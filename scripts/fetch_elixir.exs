#!/usr/bin/env nix-shell
#! nix-shell -i elixir -p elixir_1_18

Mix.install([
  {:req, "~> 0.4.0"}
])

defmodule ElixirFetcher do
  @github_api_url "https://api.github.com/repos/elixir-lang/elixir/releases"
  @manifests_file "../manifests/stable/default.nix"
  @manifests_dir "../manifests/stable"

  def run do
    IO.puts("Fetching Elixir releases...")

    case fetch_releases() do
      {:ok, releases} ->
        current_versions = load_current_versions()
        new_versions = find_new_versions(releases, current_versions)

        if Enum.empty?(new_versions) do
          IO.puts("No new versions found.")
        else
          IO.puts("Found #{length(new_versions)} new version(s):")
          Enum.each(new_versions, &IO.puts("  - #{&1}"))

          updated_manifests = fetch_and_update_manifests(new_versions)
          write_manifests(updated_manifests)
          IO.puts("Manifests updated successfully!")
        end

      {:error, reason} ->
        IO.puts("Error fetching releases: #{reason}")
        System.halt(1)
    end
  end

  defp fetch_releases do
    headers =
      case System.get_env("GITHUB_TOKEN") do
        nil -> []
        token -> [{"Authorization", "Bearer #{token}"}]
      end

    case Req.get(@github_api_url, headers: headers) do
      {:ok, %{status: 200, body: releases}} ->
        stable_releases =
          releases
          |> Enum.reject(& &1["draft"])
          |> Enum.filter(&valid_version?(&1["tag_name"]))
          |> Enum.map(fn release ->
            version = String.replace_leading(release["tag_name"], "v", "")
            {version, release["tarball_url"]}
          end)
          |> Enum.sort_by(fn {version, _} -> Version.parse!(version) end, :desc)

        {:ok, stable_releases}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp valid_version?(tag) do
    String.match?(tag, ~r/^v\d+\.\d+\.\d+(-rc\.\d+)?$/)
  end

  defp load_current_versions do
    manifests_path = Path.expand(@manifests_file, __DIR__)

    if File.exists?(manifests_path) do
      content = File.read!(manifests_path)

      Regex.scan(~r/"([\d\.\-rc]+)" = \{/, content)
      |> Enum.map(fn [_, version] -> version end)
      |> MapSet.new()
    else
      MapSet.new()
    end
  end

  defp find_new_versions(releases, current_versions) do
    releases
    |> Enum.map(fn {version, _} -> version end)
    |> Enum.reject(&MapSet.member?(current_versions, &1))
  end

  defp fetch_and_update_manifests(new_versions) do
    all_versions = fetch_all_version_data(new_versions)

    all_versions
    |> Enum.sort_by(fn {version, _} -> Version.parse!(version) end, :desc)
    |> Map.new()
  end

  defp fetch_all_version_data(new_versions) do
    existing_data = load_existing_version_data()

    new_data =
      new_versions
      |> Enum.map(&fetch_version_data/1)
      |> Enum.filter(&(&1 != nil))
      |> Map.new()

    Map.merge(existing_data, new_data)
  end

  defp load_existing_version_data do
    manifests_path = Path.expand(@manifests_file, __DIR__)

    if File.exists?(manifests_path) do
      content = File.read!(manifests_path)

      Regex.scan(
        ~r/"([\d\.\-rc]+)" = \{\s*sha256 = "([^"]+)";\s*url = "([^"]+)";\s*minOtpVersion = "(\d+)";\s*maxOtpVersion = "(\d+)";\s*\}/s,
        content
      )
      |> Enum.map(fn [_, version, sha256, url, min_otp, max_otp] ->
        {version,
         %{
           sha256: sha256,
           url: url,
           min_otp_version: min_otp,
           max_otp_version: max_otp
         }}
      end)
      |> Map.new()
    else
      %{}
    end
  end

  defp fetch_version_data(version) do
    url = "https://codeload.github.com/elixir-lang/elixir/tar.gz/refs/tags/v#{version}"

    IO.puts("Fetching SHA256 for Elixir #{version}...")

    case System.cmd("nix-prefetch-url", [url]) do
      {sha256, 0} ->
        sha256 = String.trim(sha256)
        {min_otp, max_otp} = determine_otp_compatibility(version)

        {version,
         %{
           sha256: sha256,
           url: url,
           min_otp_version: min_otp,
           max_otp_version: max_otp
         }}

      {error, _} ->
        IO.puts("Failed to fetch SHA256 for #{version}: #{error}")
        nil
    end
  end

  defp determine_otp_compatibility(version) do
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

  defp write_manifests(versions_data) do
    manifests_dir = Path.expand(@manifests_dir, __DIR__)
    File.mkdir_p!(manifests_dir)

    content = generate_manifests_content(versions_data)

    manifests_path = Path.expand(@manifests_file, __DIR__)
    File.write!(manifests_path, content)
  end

  defp generate_manifests_content(versions_data) do
    versions_nix =
      versions_data
      |> Enum.sort_by(fn {version, _} -> Version.parse!(version) end, :desc)
      |> Enum.map(fn {version, data} ->
        ~s(    "#{version}" = {
      sha256 = "#{data.sha256}";
      url = "#{data.url}";
      minOtpVersion = "#{data.min_otp_version}";
      maxOtpVersion = "#{data.max_otp_version}";
    };)
      end)
      |> Enum.join("\n")

    """
    {
      versions = {
    #{versions_nix}
      };
    }
    """
  end
end

ElixirFetcher.run()
