import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Modal } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import type { MapLayer } from '@/types';

interface LayerSelectorProps {
  visible: boolean;
  currentLayer: MapLayer;
  onSelectLayer: (layer: MapLayer) => void;
  onClose: () => void;
}

const LAYERS: Array<{ id: MapLayer; name: string; icon: string; description: string }> = [
  {
    id: 'topo',
    name: 'Topographic',
    icon: 'map',
    description: 'Terrain contours and elevation',
  },
  {
    id: 'satellite',
    name: 'Satellite',
    icon: 'earth',
    description: 'Aerial imagery',
  },
];

/**
 * Modal component for selecting map layer type
 */
export function LayerSelector({
  visible,
  currentLayer,
  onSelectLayer,
  onClose,
}: LayerSelectorProps) {
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <TouchableOpacity style={styles.overlay} activeOpacity={1} onPress={onClose}>
        <View style={styles.container}>
          <View style={styles.header}>
            <Text style={styles.title}>Map Layer</Text>
            <TouchableOpacity onPress={onClose} style={styles.closeButton}>
              <Ionicons name="close" size={24} color="#888" />
            </TouchableOpacity>
          </View>

          {LAYERS.map((layer) => (
            <TouchableOpacity
              key={layer.id}
              style={[styles.layerOption, currentLayer === layer.id && styles.selectedLayer]}
              onPress={() => {
                onSelectLayer(layer.id);
                onClose();
              }}
            >
              <View style={styles.layerIcon}>
                <Ionicons
                  name={layer.icon as any}
                  size={24}
                  color={currentLayer === layer.id ? '#4a9eff' : '#888'}
                />
              </View>
              <View style={styles.layerInfo}>
                <Text style={[styles.layerName, currentLayer === layer.id && styles.selectedText]}>
                  {layer.name}
                </Text>
                <Text style={styles.layerDescription}>{layer.description}</Text>
              </View>
              {currentLayer === layer.id && (
                <Ionicons name="checkmark-circle" size={24} color="#4a9eff" />
              )}
            </TouchableOpacity>
          ))}
        </View>
      </TouchableOpacity>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'flex-end',
  },
  container: {
    backgroundColor: '#1a1a2e',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 20,
    paddingBottom: 40,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
    color: '#fff',
  },
  closeButton: {
    padding: 4,
  },
  layerOption: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderRadius: 12,
    marginBottom: 8,
    backgroundColor: '#0f0f1a',
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  selectedLayer: {
    borderColor: '#4a9eff',
    backgroundColor: '#1a2a3e',
  },
  layerIcon: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#1a1a2e',
    alignItems: 'center',
    justifyContent: 'center',
  },
  layerInfo: {
    flex: 1,
    marginLeft: 12,
  },
  layerName: {
    fontSize: 16,
    fontWeight: '500',
    color: '#fff',
  },
  selectedText: {
    color: '#4a9eff',
  },
  layerDescription: {
    fontSize: 13,
    color: '#888',
    marginTop: 2,
  },
});

export default LayerSelector;
