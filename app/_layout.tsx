import { useEffect, useState } from 'react';
import { StyleSheet } from 'react-native';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { DatabaseProvider } from '@/hooks/useDatabase';

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const [appReady, setAppReady] = useState(false);

  useEffect(() => {
    async function prepare() {
      try {
        // Add any initialization logic here (e.g., load fonts, preload data)
        // For now, we'll just mark as ready immediately
        await new Promise((resolve) => setTimeout(resolve, 100));
      } catch (e) {
        console.warn('App initialization error:', e);
      } finally {
        setAppReady(true);
        SplashScreen.hideAsync();
      }
    }

    prepare();
  }, []);

  if (!appReady) {
    return null;
  }

  return (
    <GestureHandlerRootView style={styles.container}>
      <DatabaseProvider>
        <Stack
          screenOptions={{
            headerStyle: {
              backgroundColor: '#1a1a2e',
            },
            headerTintColor: '#fff',
            headerTitleStyle: {
              fontWeight: '600',
            },
            contentStyle: {
              backgroundColor: '#0f0f1a',
            },
          }}
        >
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen
            name="project/[id]"
            options={{
              title: 'Project Details',
              presentation: 'card',
            }}
          />
          <Stack.Screen
            name="waypoint/[id]"
            options={{
              title: 'Waypoint Details',
              presentation: 'card',
            }}
          />
          <Stack.Screen
            name="export/[projectId]"
            options={{
              title: 'Export Data',
              presentation: 'modal',
            }}
          />
        </Stack>
        <StatusBar style="light" />
      </DatabaseProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
