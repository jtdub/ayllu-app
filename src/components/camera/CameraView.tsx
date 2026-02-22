import React, { useRef, useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import type { LocationCoordinates } from '@/types';

// Vision Camera imports - these will work after `npx expo prebuild`
// import { Camera, useCameraDevice, useCameraPermission } from 'react-native-vision-camera';

interface CameraViewProps {
  location?: LocationCoordinates | null;
  onCapture: (photo: CapturedPhoto) => void;
  onClose: () => void;
}

export interface CapturedPhoto {
  uri: string;
  width: number;
  height: number;
  latitude: number | null;
  longitude: number | null;
  altitude: number | null;
  timestamp: string;
}

/**
 * Camera component for capturing field photos with GPS metadata
 *
 * Note: Requires development build with native modules.
 * Run `npx expo prebuild` then `npx expo run:ios` or `npx expo run:android`
 */
export function CameraView({ location, onCapture, onClose }: CameraViewProps) {
  const [isVisionCameraAvailable, setIsVisionCameraAvailable] = useState(false);
  const [isCapturing, setIsCapturing] = useState(false);
  const [flash, setFlash] = useState<'off' | 'on' | 'auto'>('auto');
  const cameraRef = useRef(null);

  useEffect(() => {
    // Check if Vision Camera is available (requires native build)
    try {
      // const { Camera } = require('react-native-vision-camera');
      // setIsVisionCameraAvailable(true);
      setIsVisionCameraAvailable(false); // Set to false until native build
    } catch {
      setIsVisionCameraAvailable(false);
    }
  }, []);

  const handleCapture = async () => {
    if (!cameraRef.current || isCapturing) return;

    setIsCapturing(true);

    try {
      // Vision Camera capture implementation
      /*
      const photo = await cameraRef.current.takePhoto({
        flash: flash,
        enableShutterSound: true,
      });

      onCapture({
        uri: `file://${photo.path}`,
        width: photo.width,
        height: photo.height,
        latitude: location?.latitude ?? null,
        longitude: location?.longitude ?? null,
        altitude: location?.altitude ?? null,
        timestamp: new Date().toISOString(),
      });
      */

      // Placeholder for development
      onCapture({
        uri: '',
        width: 0,
        height: 0,
        latitude: location?.latitude ?? null,
        longitude: location?.longitude ?? null,
        altitude: location?.altitude ?? null,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      console.error('Failed to capture photo:', error);
    } finally {
      setIsCapturing(false);
    }
  };

  const toggleFlash = () => {
    setFlash((current) => {
      switch (current) {
        case 'off':
          return 'on';
        case 'on':
          return 'auto';
        default:
          return 'off';
      }
    });
  };

  const getFlashIcon = () => {
    switch (flash) {
      case 'on':
        return 'flash';
      case 'off':
        return 'flash-off';
      default:
        return 'flash-outline';
    }
  };

  if (!isVisionCameraAvailable) {
    return (
      <View style={styles.container}>
        <View style={styles.placeholder}>
          <Ionicons name="camera-outline" size={80} color="#444" />
          <Text style={styles.placeholderTitle}>Camera</Text>
          <Text style={styles.placeholderText}>
            Vision Camera requires a development build.{'\n'}
            Run `npx expo prebuild` then{'\n'}
            `npx expo run:ios` or `npx expo run:android`
          </Text>

          {location && (
            <View style={styles.locationInfo}>
              <Ionicons name="location" size={16} color="#4a9eff" />
              <Text style={styles.locationText}>
                {location.latitude.toFixed(6)}, {location.longitude.toFixed(6)}
              </Text>
            </View>
          )}

          <TouchableOpacity style={styles.closeButton} onPress={onClose}>
            <Text style={styles.closeButtonText}>Close</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  // Full Vision Camera implementation (uncomment after native build)
  /*
  const device = useCameraDevice('back');
  const { hasPermission, requestPermission } = useCameraPermission();

  if (!hasPermission) {
    return (
      <View style={styles.permissionContainer}>
        <Text style={styles.permissionText}>Camera permission required</Text>
        <TouchableOpacity style={styles.permissionButton} onPress={requestPermission}>
          <Text style={styles.permissionButtonText}>Grant Permission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  if (!device) {
    return (
      <View style={styles.placeholder}>
        <ActivityIndicator size="large" color="#4a9eff" />
        <Text style={styles.placeholderText}>Loading camera...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Camera
        ref={cameraRef}
        style={StyleSheet.absoluteFill}
        device={device}
        isActive={true}
        photo={true}
        enableLocation={true}
      />

      <View style={styles.controls}>
        <TouchableOpacity style={styles.controlButton} onPress={onClose}>
          <Ionicons name="close" size={28} color="#fff" />
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.captureButton}
          onPress={handleCapture}
          disabled={isCapturing}
        >
          {isCapturing ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <View style={styles.captureInner} />
          )}
        </TouchableOpacity>

        <TouchableOpacity style={styles.controlButton} onPress={toggleFlash}>
          <Ionicons name={getFlashIcon()} size={24} color="#fff" />
        </TouchableOpacity>
      </View>

      {location && (
        <View style={styles.gpsIndicator}>
          <Ionicons name="location" size={14} color="#4a9eff" />
          <Text style={styles.gpsText}>GPS Active</Text>
        </View>
      )}
    </View>
  );
  */

  return null;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  placeholder: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#0f0f1a',
    padding: 40,
  },
  placeholderTitle: {
    fontSize: 24,
    fontWeight: '600',
    color: '#fff',
    marginTop: 16,
  },
  placeholderText: {
    fontSize: 14,
    color: '#888',
    textAlign: 'center',
    marginTop: 8,
    lineHeight: 22,
  },
  locationInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 24,
    padding: 12,
    backgroundColor: '#1a1a2e',
    borderRadius: 8,
  },
  locationText: {
    fontSize: 14,
    color: '#fff',
    marginLeft: 8,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
  },
  closeButton: {
    marginTop: 32,
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: '#2a2a4e',
    borderRadius: 8,
  },
  closeButtonText: {
    fontSize: 16,
    color: '#fff',
  },
  permissionContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#0f0f1a',
  },
  permissionText: {
    fontSize: 16,
    color: '#fff',
    marginBottom: 16,
  },
  permissionButton: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: '#4a9eff',
    borderRadius: 8,
  },
  permissionButtonText: {
    fontSize: 16,
    color: '#fff',
    fontWeight: '600',
  },
  controls: {
    position: 'absolute',
    bottom: 40,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  controlButton: {
    width: 50,
    height: 50,
    borderRadius: 25,
    backgroundColor: 'rgba(0,0,0,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  captureButton: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 4,
    borderColor: 'rgba(255,255,255,0.5)',
  },
  captureInner: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: '#fff',
  },
  gpsIndicator: {
    position: 'absolute',
    top: 60,
    left: 20,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.6)',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
  },
  gpsText: {
    fontSize: 12,
    color: '#fff',
    marginLeft: 6,
  },
});

export default CameraView;
