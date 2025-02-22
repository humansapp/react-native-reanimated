import { NativeSyntheticEvent } from 'react-native';
import { PagerViewOnPageScrollEventData, PagerViewOnPageSelectedEventData, PageScrollStateChangedEvent } from 'react-native-pager-view';
import { useEvent, useHandler } from 'react-native-reanimated';

export function useAnimatedPagerScrollHandler<TContext extends Record<string, unknown>>(
  handlers: { onPageScroll: (e: PagerViewOnPageScrollEventData, context: TContext) => void },
  dependencies?: ReadonlyArray<unknown>
): (e: NativeSyntheticEvent<PagerViewOnPageScrollEventData>) => void {
  const { context, doDependenciesDiffer } = useHandler<PagerViewOnPageScrollEventData, TContext>(handlers, dependencies);

  return useEvent<PagerViewOnPageScrollEventData>(
    (event) => {
      'worklet';
      const { onPageScroll } = handlers;

      if (onPageScroll && event.eventName.endsWith('onPageScroll')) {
        onPageScroll(event, context);
      }
    },
    ['onPageScroll'],
    doDependenciesDiffer,
  );
}

export function useAnimatedPagerScrollStateHandler<TContext extends Record<string, unknown>>(
  handlers: { onPageScrollStateChanged: (e: PageScrollStateChangedEvent, context: TContext) => void },
  dependencies?: ReadonlyArray<unknown>,
): (e: NativeSyntheticEvent<PageScrollStateChangedEvent>) => void {
  const { context, doDependenciesDiffer } = useHandler<PageScrollStateChangedEvent, TContext>(handlers, dependencies);

  return useEvent(
    (event) => {
      'worklet';
      const { onPageScrollStateChanged } = handlers;

      if (onPageScrollStateChanged && event.eventName.endsWith('onPageScrollStateChanged')) {
        onPageScrollStateChanged(event, context);
      }
    },
    ['onPageScrollStateChanged'],
    doDependenciesDiffer,
  );
}

export function useAnimatedPagerSelectedPageHandler<TContext extends Record<string, unknown>>(
  handlers: { onPageSelected: (e: PagerViewOnPageSelectedEventData, context: TContext) => void },
  dependencies?: ReadonlyArray<unknown>
): (e: NativeSyntheticEvent<PagerViewOnPageSelectedEventData>) => void {
  const { context, doDependenciesDiffer } = useHandler<PagerViewOnPageSelectedEventData, TContext>(handlers, dependencies);

  return useEvent<PagerViewOnPageSelectedEventData>(
    (event) => {
      'worklet';
      const { onPageSelected } = handlers;

      if (onPageSelected && event.eventName.endsWith('onPageSelected')) {
        onPageSelected(event, context);
      }
    },
    ['onPageSelected'],
    doDependenciesDiffer,
  );
}
