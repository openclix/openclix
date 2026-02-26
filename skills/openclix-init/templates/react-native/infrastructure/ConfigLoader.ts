import type { Config } from '../domain/ClixTypes';

export interface ConfigLoaderOptions {
  /** Default: 10_000 (10 seconds). */
  timeoutMs?: number;
  headers?: Record<string, string>;
}

const DEFAULT_TIMEOUT_MS = 10_000;

function isRemoteUrl(endpoint: string): boolean {
  return endpoint.startsWith('http://') || endpoint.startsWith('https://');
}

export async function loadConfig(
  endpoint: string,
  options?: ConfigLoaderOptions,
): Promise<Config> {
  if (!isRemoteUrl(endpoint)) {
    throw new Error(
      `Local file paths are not supported by ConfigLoader in React Native. ` +
      `Use replaceConfig() with a bundled config object instead. ` +
      `Received endpoint: "${endpoint}"`,
    );
  }

  const timeoutMs = options?.timeoutMs ?? DEFAULT_TIMEOUT_MS;

  const headers: Record<string, string> = {
    Accept: 'application/json',
    ...options?.headers,
  };

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: 'GET',
      headers,
      signal: controller.signal,
    });
  } catch (error: unknown) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(
        `Config fetch timed out after ${timeoutMs}ms for endpoint: "${endpoint}"`,
      );
    }
    throw new Error(
      `Config fetch failed for endpoint "${endpoint}": ${error instanceof Error ? error.message : String(error)}`,
    );
  } finally {
    clearTimeout(timeoutId);
  }

  if (!response.ok) {
    throw new Error(
      `Config fetch returned HTTP ${response.status} ${response.statusText} for endpoint: "${endpoint}"`,
    );
  }

  let config: Config;
  try {
    config = (await response.json()) as Config;
  } catch (error: unknown) {
    throw new Error(
      `Failed to parse config JSON from endpoint "${endpoint}": ${error instanceof Error ? error.message : String(error)}`,
    );
  }

  return config;
}
