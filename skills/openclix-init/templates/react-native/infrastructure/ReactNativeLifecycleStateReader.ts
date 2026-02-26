import { AppState as ReactNativeAppState } from 'react-native';
import type { LifecycleStateReader } from '../domain/ClixTypes';

export class ReactNativeLifecycleStateReader implements LifecycleStateReader {
  private currentAppState: 'foreground' | 'background' = 'foreground';
  private appStateSubscription: { remove(): void } | null = null;

  constructor() {
    const mapAppState = (state: string): 'foreground' | 'background' =>
      state === 'active' ? 'foreground' : 'background';

    this.currentAppState = mapAppState(ReactNativeAppState.currentState);
    this.appStateSubscription = ReactNativeAppState.addEventListener(
      'change',
      (nextState) => {
        this.currentAppState = mapAppState(nextState);
      },
    );
  }

  getAppState(): 'foreground' | 'background' {
    return this.currentAppState;
  }

  setAppState(state: 'foreground' | 'background'): void {
    this.currentAppState = state;
  }

  dispose(): void {
    this.appStateSubscription?.remove();
    this.appStateSubscription = null;
  }
}
