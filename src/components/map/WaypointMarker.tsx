import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

interface WaypointMarkerProps {
  type: 'waypoint' | 'photo' | 'note';
  selected?: boolean;
  size?: number;
}

/**
 * Custom marker component for map waypoints
 */
export function WaypointMarker({ type, selected = false, size = 32 }: WaypointMarkerProps) {
  const getMarkerStyle = () => {
    const baseStyle = {
      width: size,
      height: size,
      borderRadius: size / 2,
      alignItems: 'center' as const,
      justifyContent: 'center' as const,
      borderWidth: selected ? 3 : 2,
      borderColor: selected ? '#fff' : 'rgba(255,255,255,0.8)',
    };

    switch (type) {
      case 'photo':
        return {
          ...baseStyle,
          backgroundColor: '#9b59b6',
        };
      case 'note':
        return {
          ...baseStyle,
          backgroundColor: '#27ae60',
        };
      case 'waypoint':
      default:
        return {
          ...baseStyle,
          backgroundColor: '#4a9eff',
        };
    }
  };

  const getIcon = () => {
    const iconSize = size * 0.5;
    switch (type) {
      case 'photo':
        return <Ionicons name="camera" size={iconSize} color="#fff" />;
      case 'note':
        return <Ionicons name="document-text" size={iconSize} color="#fff" />;
      case 'waypoint':
      default:
        return <Ionicons name="location" size={iconSize} color="#fff" />;
    }
  };

  return (
    <View style={[styles.container, selected && styles.selected]}>
      <View style={getMarkerStyle()}>{getIcon()}</View>
      {selected && <View style={styles.selectedIndicator} />}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
  },
  selected: {
    transform: [{ scale: 1.2 }],
  },
  selectedIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#fff',
    marginTop: 4,
  },
});

export default WaypointMarker;
