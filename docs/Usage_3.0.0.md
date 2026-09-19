# Usage Release 3.0.0 Documentation

> **Archived — Capacitor 3 import patterns.** JS API shape is similar, but package name and Android engine differ today: **`@brylsherbert/capacitor-video-player@8.3.0`**, Media3 on Android. See [readme.md](../readme.md).

- In your code

```ts
import { Capacitor } from '@capacitor/core';
import { CapacitorVideoPlayer } from 'capacitor-video-player';

export const setVideoPlayer = async (): Promise<any>=> {
  const platform = Capacitor.getPlatform();
  return {plugin:CapacitorVideoPlayer, platform};
};

```
