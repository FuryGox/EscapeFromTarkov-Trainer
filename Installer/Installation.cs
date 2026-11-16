using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Diagnostics.CodeAnalysis;
using System.IO;
using System.Linq;
using System.Runtime.Versioning;
using System.Text;
using Spectre.Console;

namespace Installer;

internal class Installation
{
	public Version Version { get; }
	public bool UsingSpt { get; private set; }
	public bool UsingSptButNeverRun { get; private set; }
	public bool UsingBepInEx { get; private set; }
	public string Location { get; }
	public string DisplayString { get; private set; } = string.Empty;

	public string Data => Path.Combine(Location, "EscapeFromTarkov_Data");
	public string Managed => Path.Combine(Data, "Managed");
	public string BepInEx => Path.Combine(Location, "BepInEx");
	public string BepInExCore => Path.Combine(BepInEx, "core");
	public string BepInExPlugins => Path.Combine(BepInEx, "plugins");

	private Installation(string location, Version version)
	{
		if (string.IsNullOrEmpty(location))
			throw new ArgumentException("empty location");

		Location = location;
		Version = version;
	}

	public override bool Equals(object? obj)
	{
		if (obj is not Installation other)
			return false;

		return string.Equals(other.Location, Location, StringComparison.OrdinalIgnoreCase);
	}

	public override int GetHashCode()
	{
		return StringComparer.OrdinalIgnoreCase.GetHashCode(Location);
	}

	[SupportedOSPlatform("windows")]
	public static Installation? GetTargetInstallation(string? path, string promptTitle)
	{
		var installations = new List<Installation>();

		AnsiConsole
			.Status()
			.Start("Discovering [green]Escape From Tarkov[/] installations...", _ =>
			{
				installations = [.. DiscoverInstallations().Distinct()];

				if (path is not null && TryDiscoverInstallation(path, out var installation))
					installations.Add(installation);
			});

		installations = [.. installations.Distinct().OrderBy(i => i.Location)];

		switch (installations.Count)
		{
			case 0:
				AnsiConsole.MarkupLine("[yellow]No [green]EscapeFromTarkov[/] installation found, please re-run this installer, passing the installation path as argument.[/]");
				return null;
			case 1:
				var first = installations.First();
				if (!AnsiConsole.Profile.Capabilities.Interactive)
				{
					AnsiConsole.MarkupLine($"Using [green]EscapeFromTarkov ({first.Version})[/] in [blue]{first.Location.EscapeMarkup()}[/].");
					return first;
				}
				return AnsiConsole.Confirm($"Continue with [green]EscapeFromTarkov ({first.Version})[/] in [blue]{first.Location.EscapeMarkup()}[/] ?") ? first : null;
			default:
				if (!AnsiConsole.Profile.Capabilities.Interactive)
				{
					var defaultInst = installations.FirstOrDefault(i => i.UsingSpt) ?? installations.First();
					AnsiConsole.MarkupLine($"Multiple installations found. Using [green]EscapeFromTarkov ({defaultInst.Version})[/] in [blue]{defaultInst.Location.EscapeMarkup()}[/].");
					return defaultInst;
				}
				var prompt = new SelectionPrompt<Installation> { Title = promptTitle };
				prompt.AddChoices(installations);
				return AnsiConsole.Prompt(prompt);
		}
	}

	[SupportedOSPlatform("windows")]
	private static IEnumerable<Installation> DiscoverInstallations()
	{
		if (TryDiscoverInstallation(Environment.CurrentDirectory, out var installation))
			yield return installation;

		if (TryDiscoverInstallation(Path.GetDirectoryName(AppContext.BaseDirectory), out installation))
			yield return installation;

		// SPT locations from MUI cache (covers EFT, SPT.Launcher, SPT.Server, Greed, SIM, and parent directories)
		foreach (var sptpath in Registry.GetSptInstallationsFromMuiCache())
		{
			if (TryDiscoverInstallation(sptpath, out installation))
				yield return installation;
		}

		// Common drive paths for standard SPT / Steam / Battlestate installations
		foreach (var drive in DriveInfo.GetDrives().Where(d => d.DriveType is DriveType.Fixed or DriveType.Removable).Select(d => d.RootDirectory.FullName))
		{
			string[] commonPaths = [
				Path.Combine(drive, "SPT"),
				Path.Combine(drive, "Games", "SPT"),
				Path.Combine(drive, "Games", "EscapeFromTarkov"),
				Path.Combine(drive, "Battlestate Games", "EFT"),
				Path.Combine(drive, "Battlestate Games", "EscapeFromTarkov"),
				Path.Combine(drive, "Battlestate Games", "sptarkov"),
				Path.Combine(drive, "SteamLibrary", "steamapps", "common", "Escape from Tarkov"),
				Path.Combine(drive, "Steam", "steamapps", "common", "Escape from Tarkov"),
				Path.Combine(drive, "Program Files (x86)", "Steam", "steamapps", "common", "Escape from Tarkov"),
				Path.Combine(drive, "Program Files", "Steam", "steamapps", "common", "Escape from Tarkov")
			];

			foreach (var commonPath in commonPaths)
			{
				if (TryDiscoverInstallation(commonPath, out installation))
					yield return installation;
			}
		}

		// Also check official EFT installation from registry if present
		if (Registry.TryGetEscapeFromTarkovInstallationPath(out var path))
		{
			if (TryDiscoverInstallation(path, out installation))
				yield return installation;

			var parent = Path.Combine(path, "..");
			if (Directory.Exists(parent))
			{
				foreach (var folder in Directory.EnumerateDirectories(parent))
				{
					if (TryDiscoverInstallation(folder, out installation))
						yield return installation;
				}
			}
		}
	}

	private static bool TryDiscoverInstallation(string? path, [NotNullWhen(true)] out Installation? installation)
	{
		installation = null;

		try
		{
			if (string.IsNullOrEmpty(path))
				return false;

			path = Path.GetFullPath(path.Trim('\"'));

			// If path points to an executable, use its directory
			if (File.Exists(path))
			{
				if (Path.GetFileName(path).Equals("EscapeFromTarkov.exe", StringComparison.OrdinalIgnoreCase))
					path = Path.GetDirectoryName(path);
				else
					return false;
			}

			if (string.IsNullOrEmpty(path))
				return false;

			var exe = Path.Combine(path, "EscapeFromTarkov.exe");
			if (!File.Exists(exe))
			{
				// Check if user passed an SPT subfolder like SPT, SPT_Runtime, EscapeFromTarkov_Data
				if (Path.GetDirectoryName(path) is { } parent && File.Exists(Path.Combine(parent, "EscapeFromTarkov.exe")))
				{
					path = parent;
					exe = Path.Combine(path, "EscapeFromTarkov.exe");
				}
				else
				{
					return false;
				}
			}

			var vi = FileVersionInfo.GetVersionInfo(exe);
			if (vi.FileVersion == null)
				return false;

			installation = new Installation(path, new Version(vi.FileVersion));

			if (!Directory.Exists(installation.Managed))
				return false;

			// Starting with 4.0.0, folder layout changed (SPT_Data, SPT/SPT_Data, or SPT_Runtime)
			installation.UsingSpt = Directory.Exists(Path.Combine(path, "SPT_Data"))
				|| Directory.Exists(Path.Combine(path, "SPT", "SPT_Data"))
				|| Directory.Exists(Path.Combine(path, "SPT_Runtime"));

			var battleye = Path.Combine(path, "BattlEye");
			installation.UsingSptButNeverRun = installation.UsingSpt && Directory.Exists(battleye);

			installation.UsingBepInEx = Directory.Exists(installation.BepInExPlugins);

			installation.DisplayString = installation.ComputeDisplayString();

			return true;
		}
		catch (Exception)
		{
			return false;
		}
	}

	private string ComputeDisplayString()
	{
		var sb = new StringBuilder();
		sb.Append($"{Location.EscapeMarkup()} - [[{Version}]] ");
		sb.Append(UsingSpt ? "[b]SPT[/] " : "Vanilla ");

		if (UsingSpt && VersionChecker.IsVersionSupported(Version))
			sb.Append("[green](Supported)[/]");

		return sb.ToString();
	}

	public override string ToString()
	{
		return DisplayString;
	}
}
