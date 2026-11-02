#!/usr/bin/env elixir

defmodule ManifestUpdater do
  @github_api_url "https://api.github.com/repos/elixir-lang/elixir/releases?per_page=100"
  @manifest_directory Path.expand("../manifests/elixir", __DIR__)

  def run do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    IO.puts("Fetching Elixir releases...")

    with {:ok, releases} <- fetch_releases() do
      current_versions = load_current_versions()
      new_versions = find_new_versions(releases, current_versions)

      if new_versions == [] do
        IO.puts("No new versions found.")
      else
        IO.puts("Found #{length(new_versions)} new version(s):")
        Enum.each(new_versions, &IO.puts("  - #{&1}"))

        Enum.each(new_versions, fn version ->
          case fetch_version_data(version) do
            {:ok, manifest} ->
              write_manifest(version, manifest)

            {:error, reason} ->
              IO.puts(:stderr, "Failed to update Elixir #{version}: #{reason}")
              System.halt(1)
          end
        end)

        IO.puts("Manifests updated successfully!")
      end
    else
      {:error, reason} ->
        IO.puts(:stderr, "Error fetching releases: #{reason}")
        System.halt(1)
    end
  end

  defp fetch_releases do
    case http_get(@github_api_url, github_headers()) do
      {:ok, body} ->
        with {:ok, releases} <- JSON.decode(body) do
          versions =
            releases
            |> Enum.reject(& &1["draft"])
            |> Enum.filter(&valid_version?(&1["tag_name"]))
            |> Enum.map(fn release ->
              version = String.replace_leading(release["tag_name"], "v", "")
              {version, release["tarball_url"]}
            end)
            |> Enum.sort_by(fn {version, _url} -> Version.parse!(version) end, :desc)

          {:ok, versions}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp github_headers do
    headers = [
      {"accept", "application/vnd.github+json"},
      {"user-agent", "beam-overlay-manifest-updater"}
    ]

    case System.get_env("GITHUB_TOKEN") do
      nil -> headers
      token -> [{"authorization", "Bearer #{token}"} | headers]
    end
  end

  defp http_get(url, headers) do
    request = {
      String.to_charlist(url),
      Enum.map(headers, fn {name, value} ->
        {String.to_charlist(name), String.to_charlist(value)}
      end)
    }

    request_options = [
      timeout: 30_000,
      connect_timeout: 10_000,
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]

    case :httpc.request(:get, request, request_options, body_format: :binary) do
      {:ok, {{_http_version, 200, _reason}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_http_version, status, reason}, _headers, _body}} ->
        {:error, "HTTP #{status} #{List.to_string(reason)}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp valid_version?(tag) when is_binary(tag),
    do: String.match?(tag, ~r/^v\d+\.\d+\.\d+(-rc\.\d+)?$/)

  defp valid_version?(_), do: false

  defp load_current_versions do
    @manifest_directory
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.map(&Path.basename(&1, ".json"))
    |> MapSet.new()
  end

  defp find_new_versions(releases, current_versions) do
    releases
    |> Enum.map(fn {version, _url} -> version end)
    |> Enum.reject(&MapSet.member?(current_versions, &1))
  end

  defp fetch_version_data(version) do
    url = "https://codeload.github.com/elixir-lang/elixir/tar.gz/refs/tags/v#{version}"

    IO.puts("Fetching SHA256 for Elixir #{version}...")

    case System.cmd("nix-prefetch-url", [url]) do
      {sha256, 0} ->
        {min_otp, max_otp} = otp_compatibility(version)

        {:ok,
         %{
           "sha256" => String.trim(sha256),
           "url" => url,
           "minOtpVersion" => min_otp,
           "maxOtpVersion" => max_otp
         }}

      {output, status} ->
        {:error, "nix-prefetch-url exited with status #{status}: #{output}"}
    end
  end

  defp otp_compatibility(version) do
    case Version.parse!(version) do
      %{major: 1, minor: minor} when minor >= 18 -> {"25", "28"}
      %{major: 1, minor: minor} when minor >= 17 -> {"25", "27"}
      %{major: 1, minor: minor} when minor >= 16 -> {"24", "27"}
      %{major: 1, minor: minor} when minor >= 15 -> {"24", "26"}
      %{major: 1, minor: minor} when minor >= 14 -> {"22", "26"}
      %{major: 1, minor: minor} when minor >= 13 -> {"22", "25"}
      %{major: 1, minor: minor} when minor >= 12 -> {"21", "25"}
      _ -> {"21", "24"}
    end
  end

  defp write_manifest(version, manifest) do
    File.mkdir_p!(@manifest_directory)

    manifest_path = Path.join(@manifest_directory, "#{version}.json")
    File.write!(manifest_path, JSON.encode!(manifest) <> "\n")
  end
end

ManifestUpdater.run()
