/**
 * Unity Preset Configuration
 *
 * Auto-detects and classifies Unity project folders to minimize indexing noise.
 * Used by `gitnexus unity analyze` command.
 */

import fs from 'fs/promises';
import path from 'path';
import ignore, { type Ignore } from 'ignore';
import type { Path } from 'path-scurry';
import { shouldIgnorePath, loadIgnoreRules } from './ignore-service.js';

// ============================================================================
// CURATED LISTS
// ============================================================================

/** Well-known third-party SDK folder names found in Unity Assets/ */
export const KNOWN_UNITY_SDKS: Record<string, string> = {
  'Adjust': 'Adjust SDK',
  'AppsFlyer': 'AppsFlyer SDK',
  'AVProVideo': 'AVPro Video SDK',
  'CMP Admob': 'CMP Admob',
  'Editor': 'Unity Editor Scripts',
  'Extension': 'Extension Scripts',
  'ExternalDependencyManager': 'Google EDM',
  'FacebookSDK': 'Facebook SDK',
  'Feel': 'MoreMountains Feel',
  'DOTween': 'DOTween Animation Engine',
  'Demigiant': 'DOTween/Demigiant Assets',
  'Firebase': 'Firebase SDK',
  'GoogleMobileAds': 'Google Ads SDK',
  'GooglePlayGames': 'Google Play Games',
  'IronSource': 'IronSource SDK',
  'IronSourceAdQuality': 'IronSource Ad Quality',
  'LevelPlay': 'LevelPlay SDK',
  'NuGet': 'NuGet packages',
  'TextMesh Pro': 'TextMesh Pro',
  'Plugins': 'Native plugins',
  'PlayerPrefsEditor': 'PlayerPrefs Editor',
  'Mirza Beig': 'Mirza Beig assets',
  'WebGLTemplates': 'WebGL Templates',
  'WebPlayerTemplates': 'Web Player Templates',
  'Vuforia': 'Vuforia SDK',
  'Photon': 'Photon SDK',
  'PlayFab': 'PlayFab SDK',
  'Chartboost': 'Chartboost SDK',
  'AdMob': 'AdMob SDK',
  'UnityPurchasing': 'Unity IAP',
  'Oculus': 'Oculus SDK',
  'SteamVR': 'SteamVR SDK',
  'Spine': 'Spine 2D Animation SDK',
  'MaxSdk': 'AppLovin MAX SDK',
  'AppLovinSdk': 'AppLovin SDK',
};

/** Unity directories that NEVER contain game code */
export const UNITY_ALWAYS_IGNORE_DIRS = new Set([
  'Library', 'Temp', 'Logs', 'MemoryCaptures', 'Recordings',
  'UserSettings', 'ProjectSettings', 'Packages',
  'Editor', 'Editor Default Resources', 'C', '.claude'
]);

/** Unity-specific non-code extensions (supplement to ignore-service defaults) */
export const UNITY_EXTRA_EXTENSIONS = new Set([
  '.unity', '.prefab', '.asset', '.mat', '.controller',
  '.overrideController', '.mask', '.anim', '.meta',
  '.physicMaterial', '.physicsMaterial2D', '.spriteatlas',
  '.spriteatlasv2', '.renderTexture', '.lighting',
  '.shadergraph', '.shader', '.cginc', '.compute', '.hlsl',
  '.scene', '.cubemap', '.flare', '.giparams',
  '.guiskin', '.fontsettings', '.brush',
]);

/** Folder name patterns that typically contain only assets, no code */
export const UNITY_ASSET_ONLY_PATTERNS = new Set([
  'Animation', 'Animations', 'Font', 'Fonts',
  'Matterial', 'Materials', 'Particle', 'Particles',
  'Prefabs', 'Resources', 'Scenes', 'Sound', 'Sounds',
  'Sprite', 'Sprites', 'Sprite Atlas',
  'StreamingAssets', 'AddressableAssetsData', 'Localization',
  'GeneratedLocalRepo', 'MoreGame', 'Textures', 'Models',
]);

/** Root-level file patterns to ignore in Unity projects */
const UNITY_ROOT_IGNORE_PATTERNS = [
  '*.csproj', '*.slnx', '*.sln', 'mono_crash.*',
  '*.keystore', '*.blob',
  // Specific config files
  'AGENTS.md', 'CLAUDE.md', 'Claude.md',
  'ignore.conf', 'omnisharp.json', 'omisharp.json',
  'google-services*', 'Nuget.config', 'NuGet.Config', 'packages.config',
];

// ============================================================================
// UNITY PROJECT DETECTION
// ============================================================================

/** Check if a directory is a Unity project (has Assets/ and ProjectSettings/) */
export async function isUnityProject(repoPath: string): Promise<boolean> {
  try {
    const [assets, settings] = await Promise.all([
      fs.stat(path.join(repoPath, 'Assets')),
      fs.stat(path.join(repoPath, 'ProjectSettings')),
    ]);
    return assets.isDirectory() && settings.isDirectory();
  } catch {
    return false;
  }
}

// ============================================================================
// ASSET SCANNING & CLASSIFICATION
// ============================================================================

export interface ScannedFolder {
  name: string;
  description: string;
  csFileCount: number;
  category: 'sdk' | 'asset-only' | 'game';
}

/** Count .cs files recursively in a directory */
async function countCsFiles(dirPath: string): Promise<number> {
  let count = 0;
  try {
    const entries = await fs.readdir(dirPath, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dirPath, entry.name);
      if (entry.isFile() && entry.name.endsWith('.cs')) {
        count++;
      } else if (entry.isDirectory()) {
        count += await countCsFiles(fullPath);
      }
    }
  } catch {
    // Permission denied or other errors
  }
  return count;
}

/**
 * Scan Assets/ subfolders and classify each as SDK, asset-only, or game code.
 */
export async function scanUnityAssets(repoPath: string): Promise<ScannedFolder[]> {
  const assetsPath = path.join(repoPath, 'Assets');
  const folders: ScannedFolder[] = [];

  try {
    const entries = await fs.readdir(assetsPath, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;

      const name = entry.name;
      const folderPath = path.join(assetsPath, name);
      const csCount = await countCsFiles(folderPath);

      // Classify
      if (KNOWN_UNITY_SDKS[name]) {
        folders.push({
          name,
          description: KNOWN_UNITY_SDKS[name],
          csFileCount: csCount,
          category: 'sdk',
        });
      } else if (UNITY_ASSET_ONLY_PATTERNS.has(name)) {
        folders.push({
          name,
          description: 'Asset-only folder',
          csFileCount: csCount,
          category: 'asset-only',
        });
      } else {
        folders.push({
          name,
          description: csCount > 0 ? `${csCount} .cs files` : 'No code files',
          csFileCount: csCount,
          category: csCount > 0 ? 'game' : 'asset-only',
        });
      }
    }
  } catch (err) {
    console.warn(`  Warning: could not scan Assets/: ${(err as Error).message}`);
  }

  // Sort: game first, then sdk, then asset-only
  const order = { game: 0, sdk: 1, 'asset-only': 2 };
  folders.sort((a, b) => order[a.category] - order[b.category] || a.name.localeCompare(b.name));

  return folders;
}

// ============================================================================
// UNITY CONFIG (unity.json) PERSISTENCE
// ============================================================================

export interface UnityConfig {
  /** Folder names to ignore */
  ignored: string[];
  /** Folder names to index */
  included: string[];
  /** Last scan timestamp */
  lastScanAt: string;
}

function getUnityConfigPath(storagePath: string): string {
  return path.join(storagePath, 'unity.json');
}

/** Load unity.json from .gitnexus/ storage */
export async function loadUnityConfig(storagePath: string): Promise<UnityConfig | null> {
  try {
    const raw = await fs.readFile(getUnityConfigPath(storagePath), 'utf-8');
    return JSON.parse(raw) as UnityConfig;
  } catch {
    return null;
  }
}

/** Save unity.json to .gitnexus/ storage */
export async function saveUnityConfig(storagePath: string, config: UnityConfig): Promise<void> {
  await fs.mkdir(storagePath, { recursive: true });
  await fs.writeFile(
    getUnityConfigPath(storagePath),
    JSON.stringify(config, null, 2) + '\n',
    'utf-8'
  );
}

// ============================================================================
// UNITY IGNORE FILTER
// ============================================================================

/**
 * Create a glob-compatible ignore filter for Unity projects.
 * Merges: Unity preset rules + unity.json config + .gitnexusignore
 */
export async function createUnityIgnoreFilter(
  repoPath: string,
  config: UnityConfig,
) {
  // Load user's .gitnexusignore (if any)
  const userIg = await loadIgnoreRules(repoPath, { noGitignore: true });

  // Build ignore instance for Unity root patterns + ignored folder paths
  const unityIg = ignore();
  unityIg.add(UNITY_ROOT_IGNORE_PATTERNS);

  // Add ignored folders as Assets/<name>/
  for (const name of config.ignored) {
    unityIg.add(`Assets/${name}/`);
  }

  // Build set of always-ignored directory names for fast lookup
  const alwaysIgnoreDirSet = new Set(UNITY_ALWAYS_IGNORE_DIRS);

  // Also ignore "Editor" subdirectories within Assets subfolders
  // e.g., Assets/_Game/Editor/ should be ignored
  const editorSubfolderCheck = (rel: string): boolean => {
    const parts = rel.split('/');
    for (const part of parts) {
      if (part === 'Editor' || part === 'Editor Default Resources') return true;
    }
    return false;
  };

  return {
    ignored(p: Path): boolean {
      const rel = p.relative();
      if (!rel) return false;

      // Unity always-ignore dirs (Library/, Temp/, etc.)
      const parts = rel.split('/');
      for (const part of parts) {
        if (alwaysIgnoreDirSet.has(part)) return true;
      }

      // Editor subfolders anywhere in Assets/
      if (editorSubfolderCheck(rel)) return true;

      // Unity root patterns (*.csproj, *.sln, etc.)
      if (unityIg.ignores(rel)) return true;

      // User's .gitnexusignore
      if (userIg && userIg.ignores(rel)) return true;

      // Unity extra extensions
      const fileName = parts[parts.length - 1].toLowerCase();
      const lastDot = fileName.lastIndexOf('.');
      if (lastDot !== -1) {
        const ext = fileName.substring(lastDot);
        if (UNITY_EXTRA_EXTENSIONS.has(ext)) return true;
      }

      // Fall back to default ignore rules (IGNORED_EXTENSIONS, IGNORED_FILES, etc.)
      return shouldIgnorePath(rel);
    },

    childrenIgnored(p: Path): boolean {
      const name = p.name;

      // Unity always-ignore dirs
      if (alwaysIgnoreDirSet.has(name)) return true;

      // Editor subdirectories
      if (name === 'Editor' || name === 'Editor Default Resources') return true;

      // Ignored SDK/asset folders under Assets/
      const rel = p.relative();
      if (rel) {
        if (unityIg.ignores(rel) || unityIg.ignores(rel + '/')) return true;
        if (userIg && (userIg.ignores(rel) || userIg.ignores(rel + '/'))) return true;
      }

      return false;
    },
  };
}
