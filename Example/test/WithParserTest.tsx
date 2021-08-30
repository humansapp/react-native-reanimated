import Animated, {
  useSharedValue,
  withTiming,
  useAnimatedStyle,
  Easing,
  withParser,
} from 'react-native-reanimated';
import { View, Button } from 'react-native';
import React from 'react';

export default function WithParserTest(): React.ReactElement {
  const randomWidth = useSharedValue(10);

  const config = {
    duration: 500,
    easing: Easing.bezier(0.5, 0.01, 0, 1),
  };

  const style = useAnimatedStyle(() => {
    const style = {
      width: withParser(
        (value) => value * 2,
        withTiming(randomWidth.value, config)
      ),
    };

    return style;
  });

  return (
    <View
      style={{
        flex: 1,
        flexDirection: 'column',
        padding: 20,
      }}>
      <Animated.View
        style={[
          { width: 100, height: 80, backgroundColor: 'black', margin: 30 },
          style,
        ]}
      />
      <Button
        title="toggle"
        onPress={() => {
          randomWidth.value = Math.random() * 350;
        }}
      />
    </View>
  );
}
