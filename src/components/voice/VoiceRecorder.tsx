import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Animated,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Audio } from 'expo-av';

interface VoiceRecorderProps {
  onRecordingComplete: (recording: RecordingData) => void;
  onCancel?: () => void;
  maxDuration?: number; // seconds
}

export interface RecordingData {
  uri: string;
  duration: number; // milliseconds
  filename: string;
}

/**
 * Voice recorder component with visual feedback
 */
export function VoiceRecorder({
  onRecordingComplete,
  onCancel,
  maxDuration = 300, // 5 minutes default
}: VoiceRecorderProps) {
  const [isRecording, setIsRecording] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [duration, setDuration] = useState(0);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);

  const recordingRef = useRef<Audio.Recording | null>(null);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const pulseAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    checkPermission();
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
      stopRecording(false);
    };
  }, []);

  useEffect(() => {
    if (isRecording && !isPaused) {
      Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.2,
            duration: 500,
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: 500,
            useNativeDriver: true,
          }),
        ])
      ).start();
    } else {
      pulseAnim.setValue(1);
    }
  }, [isRecording, isPaused]);

  const checkPermission = async () => {
    const { status } = await Audio.requestPermissionsAsync();
    setHasPermission(status === 'granted');
  };

  const startRecording = async () => {
    if (!hasPermission) {
      await checkPermission();
      return;
    }

    try {
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });

      const { recording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );

      recordingRef.current = recording;
      setIsRecording(true);
      setDuration(0);

      // Start timer
      timerRef.current = setInterval(() => {
        setDuration((prev) => {
          if (prev >= maxDuration * 1000) {
            stopRecording(true);
            return prev;
          }
          return prev + 100;
        });
      }, 100);
    } catch (error) {
      console.error('Failed to start recording:', error);
    }
  };

  const stopRecording = async (save: boolean) => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }

    if (!recordingRef.current) return;

    try {
      await recordingRef.current.stopAndUnloadAsync();
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: false,
      });

      if (save) {
        const uri = recordingRef.current.getURI();
        if (uri) {
          const filename = `recording_${Date.now()}.m4a`;
          onRecordingComplete({
            uri,
            duration,
            filename,
          });
        }
      }
    } catch (error) {
      console.error('Failed to stop recording:', error);
    }

    recordingRef.current = null;
    setIsRecording(false);
    setIsPaused(false);
    setDuration(0);
  };

  const togglePause = async () => {
    if (!recordingRef.current) return;

    try {
      if (isPaused) {
        await recordingRef.current.startAsync();
        timerRef.current = setInterval(() => {
          setDuration((prev) => prev + 100);
        }, 100);
      } else {
        await recordingRef.current.pauseAsync();
        if (timerRef.current) {
          clearInterval(timerRef.current);
          timerRef.current = null;
        }
      }
      setIsPaused(!isPaused);
    } catch (error) {
      console.error('Failed to toggle pause:', error);
    }
  };

  const formatDuration = (ms: number): string => {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  };

  if (hasPermission === false) {
    return (
      <View style={styles.container}>
        <Ionicons name="mic-off" size={48} color="#ff6b6b" />
        <Text style={styles.permissionText}>
          Microphone permission required
        </Text>
        <TouchableOpacity style={styles.permissionButton} onPress={checkPermission}>
          <Text style={styles.permissionButtonText}>Grant Permission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Recording indicator */}
      <View style={styles.visualizer}>
        <Animated.View
          style={[
            styles.recordingCircle,
            isRecording && !isPaused && styles.recordingActive,
            { transform: [{ scale: pulseAnim }] },
          ]}
        >
          <Ionicons
            name={isRecording ? (isPaused ? 'pause' : 'mic') : 'mic-outline'}
            size={40}
            color={isRecording ? '#fff' : '#4a9eff'}
          />
        </Animated.View>

        <Text style={styles.duration}>{formatDuration(duration)}</Text>
        <Text style={styles.maxDuration}>/ {formatDuration(maxDuration * 1000)}</Text>
      </View>

      {/* Controls */}
      <View style={styles.controls}>
        {!isRecording ? (
          <TouchableOpacity style={styles.recordButton} onPress={startRecording}>
            <View style={styles.recordButtonInner} />
          </TouchableOpacity>
        ) : (
          <>
            <TouchableOpacity
              style={styles.controlButton}
              onPress={() => stopRecording(false)}
            >
              <Ionicons name="close" size={24} color="#ff6b6b" />
            </TouchableOpacity>

            <TouchableOpacity style={styles.pauseButton} onPress={togglePause}>
              <Ionicons
                name={isPaused ? 'play' : 'pause'}
                size={28}
                color="#fff"
              />
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.controlButton}
              onPress={() => stopRecording(true)}
            >
              <Ionicons name="checkmark" size={24} color="#4a9eff" />
            </TouchableOpacity>
          </>
        )}
      </View>

      {onCancel && !isRecording && (
        <TouchableOpacity style={styles.cancelButton} onPress={onCancel}>
          <Text style={styles.cancelText}>Cancel</Text>
        </TouchableOpacity>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    padding: 24,
    backgroundColor: '#1a1a2e',
    borderRadius: 16,
  },
  visualizer: {
    alignItems: 'center',
    marginBottom: 24,
  },
  recordingCircle: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: '#2a2a4e',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  recordingActive: {
    backgroundColor: '#ff6b6b',
  },
  duration: {
    fontSize: 36,
    fontWeight: '600',
    color: '#fff',
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
  },
  maxDuration: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  recordButton: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: '#ff6b6b',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 4,
    borderColor: 'rgba(255,107,107,0.3)',
  },
  recordButtonInner: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: '#fff',
  },
  controlButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#2a2a4e',
    alignItems: 'center',
    justifyContent: 'center',
  },
  pauseButton: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: '#4a9eff',
    alignItems: 'center',
    justifyContent: 'center',
    marginHorizontal: 24,
  },
  cancelButton: {
    marginTop: 16,
    padding: 12,
  },
  cancelText: {
    fontSize: 15,
    color: '#888',
  },
  permissionText: {
    fontSize: 16,
    color: '#fff',
    marginTop: 16,
    marginBottom: 16,
  },
  permissionButton: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: '#4a9eff',
    borderRadius: 8,
  },
  permissionButtonText: {
    fontSize: 15,
    color: '#fff',
    fontWeight: '600',
  },
});

export default VoiceRecorder;
