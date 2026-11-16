using System;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.IO;
using System.Linq;
using System.Runtime.Versioning;
using Microsoft.Win32;

namespace Installer
{
	[SupportedOSPlatform("windows")]
	internal class Registry
	{
		public static bool TryGetEscapeFromTarkovInstallationPath([NotNullWhen(true)] out string? installationPath)
		{
			installationPath = null;

			try
			{
				RegistryHive[] hives = [RegistryHive.LocalMachine, RegistryHive.CurrentUser];
				RegistryView[] views = [RegistryView.Registry32, RegistryView.Registry64];

				foreach (var h in hives)
				{
					foreach (var v in views)
					{
						using var hive = RegistryKey.OpenBaseKey(h, v);
						using var eft = hive.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\EscapeFromTarkov", false);

						if (eft == null)
							continue;

						var exe = (eft.GetValue("DisplayIcon") ?? eft.GetValue("InstallLocation")) as string;
						if (string.IsNullOrEmpty(exe))
							continue;

						var path = File.Exists(exe) ? Path.GetDirectoryName(exe) : exe;
						if (string.IsNullOrEmpty(path) || !Directory.Exists(path))
							continue;

						installationPath = path;
						return true;
					}
				}

				return false;
			}
			catch
			{
				return false;
			}
		}

		public static IEnumerable<string> GetSptInstallationsFromMuiCache()
		{
			var results = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

			try
			{
				RegistryView[] views = [RegistryView.Default, RegistryView.Registry64, RegistryView.Registry32];
				string[] candidateFiles = ["EscapeFromTarkov.exe", "SPT.Launcher.exe", "SPT.Server.exe", "Greed.exe", "SIM.exe", "BsgLauncher.exe"];

				foreach (var v in views)
				{
					using var hive = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, v);
					using var mui = hive.OpenSubKey(@"Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache", false);

					if (mui == null)
						continue;

					foreach (var valueName in mui.GetValueNames())
					{
						var idx = valueName.IndexOf(".exe", StringComparison.OrdinalIgnoreCase);
						if (idx < 0)
							continue;

						var exePath = valueName.Substring(0, idx + 4);
						var fileName = Path.GetFileName(exePath);

						if (!candidateFiles.Any(c => string.Equals(c, fileName, StringComparison.OrdinalIgnoreCase)))
							continue;

						var dir = Path.GetDirectoryName(exePath);
						if (string.IsNullOrEmpty(dir))
							continue;

						results.Add(dir);

						if (Path.GetDirectoryName(dir) is { } parent)
						{
							results.Add(parent);
							if (Path.GetDirectoryName(parent) is { } grandParent)
								results.Add(grandParent);
						}
					}
				}
			}
			catch
			{
				// Ignore registry read errors
			}

			return results;
		}
	}
}
