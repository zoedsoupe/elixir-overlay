#!/usr/bin/env elixir

defmodule ManifestUpdater do
  @github_api_url "https://api.github.com/repos/elixir-lang/elixir/releases?per_page=100"
  @manifest_directory Path.expand("../manifests/elixir", __DIR__)
  @otp_github_api_url "https://api.github.com/repos/erlang/otp/releases"
  @otp_manifest_directory Path.expand("../manifests/erlang-otp", __DIR__)
  @supported_otp_majors ["26", "27", "28", "29"]

  def run do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    with :ok <- update_elixir_manifests(),
         :ok <- update_otp_manifests() do
      IO.puts("Manifests updated successfully!")
    else
      {:error, reason} ->
        IO.puts(:stderr, reason)
        System.halt(1)
    end
  end

  defp update_elixir_manifests do
    IO.puts("Fetching Elixir releases...")

    with {:ok, releases} <- fetch_releases() do
      current_versions = load_current_versions(@manifest_directory)
      new_versions = find_new_versions(releases, current_versions)

      if new_versions == [] do
        IO.puts("No new Elixir versions found.")
        :ok
      else
        IO.puts("Found #{length(new_versions)} new Elixir version(s):")
        Enum.each(new_versions, &IO.puts("  - #{&1}"))

        Enum.reduce_while(new_versions, :ok, fn version, :ok ->
          case fetch_version_data(version) do
            {:ok, manifest} ->
              write_manifest(@manifest_directory, version, manifest)
              {:cont, :ok}

            {:error, reason} ->
              {:halt, {:error, "Failed to update Elixir #{version}: #{reason}"}}
          end
        end)
      end
    else
      {:error, reason} -> {:error, "Error fetching Elixir releases: #{reason}"}
    end
  end

  defp update_otp_manifests do
    IO.puts("Fetching Erlang/OTP releases...")

    with {:ok, releases} <- fetch_otp_releases() do
      current_versions = load_current_versions(@otp_manifest_directory)
      new_releases = newest_otp_releases(releases, current_versions)

      if new_releases == [] do
        IO.puts("No new Erlang/OTP minor-series releases found.")
        :ok
      else
        IO.puts("Found #{length(new_releases)} new Erlang/OTP version(s):")

        Enum.reduce_while(new_releases, :ok, fn {version, url}, :ok ->
          IO.puts("  - #{version}")

          case fetch_otp_version_data(version, url) do
            {:ok, manifest} ->
              write_manifest(@otp_manifest_directory, version, manifest)
              {:cont, :ok}

            {:error, reason} ->
              {:halt, {:error, "Failed to update Erlang/OTP #{version}: #{reason}"}}
          end
        end)
      end
    else
      {:error, reason} -> {:error, "Error fetching Erlang/OTP releases: #{reason}"}
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

  defp fetch_otp_releases(page \\ 1, releases \\ []) do
    url = "#{@otp_github_api_url}?per_page=100&page=#{page}"

    case http_get(url, github_headers()) do
      {:ok, body} ->
        case JSON.decode(body) do
          {:ok, release_page} when is_list(release_page) ->
            parsed_releases =
              release_page
              |> Enum.reject(& &1["draft"])
              |> Enum.filter(&valid_otp_tag?(&1["tag_name"]))
              |> Enum.map(fn release ->
                version = String.replace_prefix(release["tag_name"], "OTP-", "")
                url = "https://codeload.github.com/erlang/otp/tar.gz/refs/tags/OTP-#{version}"
                {version, url}
              end)

            all_releases = releases ++ parsed_releases

            if length(release_page) < 100 do
              sorted =
                Enum.sort_by(all_releases, fn {version, _url} -> otp_sort_key(version) end, :desc)

              {:ok, sorted}
            else
              fetch_otp_releases(page + 1, all_releases)
            end

          {:error, reason} ->
            {:error, inspect(reason)}

          _ ->
            {:error, "GitHub returned an invalid Erlang/OTP release list."}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp valid_otp_tag?(tag) when is_binary(tag) do
    major_pattern = Enum.join(@supported_otp_majors, "|")
    String.match?(tag, Regex.compile!("^OTP-(?:#{major_pattern})\\.\\d+(?:\\.\\d+)*$"))
  end

  defp valid_otp_tag?(_), do: false

  defp otp_sort_key(version) do
    version
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
  end

  defp otp_minor_series(version),
    do: version |> String.split(".") |> Enum.take(2) |> Enum.join(".")

  defp newest_otp_releases(releases, current_versions) do
    current_by_minor =
      current_versions
      |> Enum.group_by(&otp_minor_series/1)
      |> Map.new(fn {minor, versions} -> {minor, Enum.max_by(versions, &otp_sort_key/1)} end)

    releases
    |> Enum.group_by(fn {version, _url} -> otp_minor_series(version) end)
    |> Enum.map(fn {minor, minor_releases} ->
      {version, url} =
        Enum.max_by(minor_releases, fn {candidate, _url} -> otp_sort_key(candidate) end)

      case Map.get(current_by_minor, minor) do
        nil -> {version, url}
        current -> if otp_sort_key(version) > otp_sort_key(current), do: {version, url}, else: nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {version, _url} -> otp_sort_key(version) end)
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

  defp valid_version?(tag) when is_binary(tag) do
    if String.match?(tag, ~r/^v\d+\.\d+\.\d+(-rc\.\d+)?$/) do
      case Version.parse(String.replace_prefix(tag, "v", "")) do
        {:ok, %Version{major: 1, minor: minor}} -> minor >= 15
        _ -> false
      end
    else
      false
    end
  end

  defp valid_version?(_), do: false

  defp load_current_versions(directory) do
    directory
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

  defp fetch_otp_version_data(version, url) do
    IO.puts("Fetching SHA256 for Erlang/OTP #{version}...")

    case System.cmd("nix-prefetch-url", ["--unpack", url]) do
      {base32, 0} ->
        with {:ok, hash} <- sri_sha256(base32) do
          {:ok, %{"hash" => hash}}
        end

      {output, status} ->
        {:error, "nix-prefetch-url exited with status #{status}: #{output}"}
    end
  end

  defp sri_sha256(base32) do
    with {hex, 0} <-
           System.cmd("nix-hash", ["--type", "sha256", "--to-base16", String.trim(base32)]),
         {sri, 0} <- System.cmd("nix-hash", ["--type", "sha256", "--to-sri", String.trim(hex)]) do
      {:ok, String.trim(sri)}
    else
      {output, status} -> {:error, "nix-hash exited with status #{status}: #{output}"}
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

  defp write_manifest(directory, version, manifest) do
    File.mkdir_p!(directory)

    manifest_path = Path.join(directory, "#{version}.json")
    File.write!(manifest_path, JSON.encode!(manifest) <> "\n")
  end
end

ManifestUpdater.run()
