import { useEffect, useState } from 'react';
import { StyleSheet, View, Text, ActivityIndicator } from 'react-native';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { DatabaseProvider, useDatabase } from '@/hooks/useDatabase';

// Prevent the splash screen from auto-hiding
SplashScreen.preventAutoHideAsync().catch(() => {
  // Ignore errors - splash screen may already be hidden
});

function AppContent() {
  const { isReady, error } = useDatabase();
  const [splashHidden, setSplashHidden] = useState(false);

  useEffect(() => {
    if (isReady && !splashHidden) {
      SplashScreen.hideAsync()
        .catch(() => {
          // Ignore errors
        })
        .finally(() => {
          setSplashHidden(true);
        });
    }
  }, [isReady, splashHidden]);

  // Show error state
  if (error) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorTitle}>Database Error</Text>
        <Text style={styles.errorText}>{error.message}</Text>
      </View>
    );
  }

  // Show loading state while database initializes
  if (!isReady) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" color="#4a9eff" />
        <Text style={styles.loadingText}>Initializing...</Text>
      </View>
    );
  }

  return (
    <>
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
    </>
  );
}

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={styles.container}>
      <DatabaseProvider>
        <AppContent />
      </DatabaseProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#0f0f1a',
    padding: 20,
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#888',
  },
  errorTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#ff6b6b',
    marginBottom: 8,
  },
  errorText: {
    fontSize: 14,
    color: '#888',
    textAlign: 'center',
  },
});
