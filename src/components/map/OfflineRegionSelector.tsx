import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Modal,
  TextInput,
  Switch,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import type { BoundingBox, MapLayer } from '@/types';
import { formatFileSize, calculateTileCount, estimateDownloadSize } from '@/utils';

interface OfflineRegionSelectorProps {
  visible: boolean;
  bounds: BoundingBox | null;
  onDownload: (config: OfflineDownloadConfig) => void;
  onClose: () => void;
  isDownloading?: boolean;
  downloadProgress?: number;
}

export interface OfflineDownloadConfig {
  name: string;
  bounds: BoundingBox;
  minZoom: number;
  maxZoom: number;
  layers: MapLayer[];
}

const ZOOM_LEVELS = [
  { value: 10, label: 'Regional (10)' },
  { value: 12, label: 'City (12)' },
  { value: 14, label: 'Neighborhood (14)' },
  { value: 16, label: 'Street (16)' },
  { value: 18, label: 'Building (18)' },
];

/**
 * Modal for configuring offline map region downloads
 */
export function OfflineRegionSelector({
  visible,
  bounds,
  onDownload,
  onClose,
  isDownloading = false,
  downloadProgress = 0,
}: OfflineRegionSelectorProps) {
  const [name, setName] = useState('');
  const [minZoom, setMinZoom] = useState(10);
  const [maxZoom, setMaxZoom] = useState(16);
  const [includeTopo, setIncludeTopo] = useState(true);
  const [includeSatellite, setIncludeSatellite] = useState(false);

  const layers: MapLayer[] = [];
  if (includeTopo) layers.push('topo');
  if (includeSatellite) layers.push('satellite');

  const tileCount = bounds
    ? calculateTileCount(bounds, minZoom, maxZoom) * layers.length
    : 0;
  const estimatedSize = estimateDownloadSize(tileCount);

  const handleDownload = () => {
    if (!bounds || !name.trim() || layers.length === 0) return;

    onDownload({
      name: name.trim(),
      bounds,
      minZoom,
      maxZoom,
      layers,
    });
  };

  const canDownload = bounds && name.trim() && layers.length > 0 && !isDownloading;

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
    >
      <View style={styles.overlay}>
        <View style={styles.container}>
          <View style={styles.header}>
            <Text style={styles.title}>Download Offline Region</Text>
            <TouchableOpacity onPress={onClose} style={styles.closeButton}>
              <Ionicons name="close" size={24} color="#888" />
            </TouchableOpacity>
          </View>

          {!bounds ? (
            <View style={styles.noBounds}>
              <Ionicons name="map-outline" size={48} color="#444" />
              <Text style={styles.noBoundsText}>
                Pan and zoom to select a region, then open this menu again.
              </Text>
            </View>
          ) : (
            <>
              {/* Region name */}
              <View style={styles.inputGroup}>
                <Text style={styles.label}>Region Name</Text>
                <TextInput
                  style={styles.textInput}
                  value={name}
                  onChangeText={setName}
                  placeholder="e.g., Field Site A"
                  placeholderTextColor="#666"
                />
              </View>

              {/* Zoom range */}
              <View style={styles.inputGroup}>
                <Text style={styles.label}>Zoom Range</Text>
                <View style={styles.zoomSelector}>
                  <View style={styles.zoomColumn}>
                    <Text style={styles.zoomLabel}>Min</Text>
                    {ZOOM_LEVELS.slice(0, 3).map((z) => (
                      <TouchableOpacity
                        key={z.value}
                        style={[
                          styles.zoomOption,
                          minZoom === z.value && styles.zoomSelected,
                        ]}
                        onPress={() => setMinZoom(z.value)}
                      >
                        <Text
                          style={[
                            styles.zoomOptionText,
                            minZoom === z.value && styles.zoomSelectedText,
                          ]}
                        >
                          {z.label}
                        </Text>
                      </TouchableOpacity>
                    ))}
                  </View>
                  <View style={styles.zoomColumn}>
                    <Text style={styles.zoomLabel}>Max</Text>
                    {ZOOM_LEVELS.slice(2).map((z) => (
                      <TouchableOpacity
                        key={z.value}
                        style={[
                          styles.zoomOption,
                          maxZoom === z.value && styles.zoomSelected,
                        ]}
                        onPress={() => setMaxZoom(z.value)}
                      >
                        <Text
                          style={[
                            styles.zoomOptionText,
                            maxZoom === z.value && styles.zoomSelectedText,
                          ]}
                        >
                          {z.label}
                        </Text>
                      </TouchableOpacity>
                    ))}
                  </View>
                </View>
              </View>

              {/* Layers */}
              <View style={styles.inputGroup}>
                <Text style={styles.label}>Map Layers</Text>
                <View style={styles.layerRow}>
                  <Text style={styles.layerName}>Topographic</Text>
                  <Switch
                    value={includeTopo}
                    onValueChange={setIncludeTopo}
                    trackColor={{ false: '#2a2a4e', true: '#4a9eff' }}
                    thumbColor="#fff"
                  />
                </View>
                <View style={styles.layerRow}>
                  <Text style={styles.layerName}>Satellite</Text>
                  <Switch
                    value={includeSatellite}
                    onValueChange={setIncludeSatellite}
                    trackColor={{ false: '#2a2a4e', true: '#4a9eff' }}
                    thumbColor="#fff"
                  />
                </View>
              </View>

              {/* Estimate */}
              <View style={styles.estimate}>
                <View style={styles.estimateRow}>
                  <Text style={styles.estimateLabel}>Tiles</Text>
                  <Text style={styles.estimateValue}>
                    {tileCount.toLocaleString()}
                  </Text>
                </View>
                <View style={styles.estimateRow}>
                  <Text style={styles.estimateLabel}>Est. Size</Text>
                  <Text style={styles.estimateValue}>
                    {formatFileSize(estimatedSize)}
                  </Text>
                </View>
              </View>

              {/* Download progress */}
              {isDownloading && (
                <View style={styles.progressContainer}>
                  <View style={styles.progressBar}>
                    <View
                      style={[
                        styles.progressFill,
                        { width: `${downloadProgress * 100}%` },
                      ]}
                    />
                  </View>
                  <Text style={styles.progressText}>
                    {Math.round(downloadProgress * 100)}% complete
                  </Text>
                </View>
              )}

              {/* Download button */}
              <TouchableOpacity
                style={[
                  styles.downloadButton,
                  !canDownload && styles.downloadButtonDisabled,
                ]}
                onPress={handleDownload}
                disabled={!canDownload}
              >
                {isDownloading ? (
                  <ActivityIndicator color="#fff" />
                ) : (
                  <>
                    <Ionicons name="download" size={20} color="#fff" />
                    <Text style={styles.downloadButtonText}>Download Region</Text>
                  </>
                )}
              </TouchableOpacity>
            </>
          )}
        </View>
      </View>
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
    maxHeight: '80%',
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
  noBounds: {
    alignItems: 'center',
    padding: 40,
  },
  noBoundsText: {
    fontSize: 14,
    color: '#888',
    textAlign: 'center',
    marginTop: 16,
  },
  inputGroup: {
    marginBottom: 20,
  },
  label: {
    fontSize: 13,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 8,
  },
  textInput: {
    backgroundColor: '#0f0f1a',
    borderRadius: 8,
    padding: 12,
    color: '#fff',
    fontSize: 16,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  zoomSelector: {
    flexDirection: 'row',
  },
  zoomColumn: {
    flex: 1,
    marginRight: 8,
  },
  zoomLabel: {
    fontSize: 12,
    color: '#666',
    marginBottom: 8,
  },
  zoomOption: {
    padding: 10,
    borderRadius: 8,
    backgroundColor: '#0f0f1a',
    marginBottom: 4,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  zoomSelected: {
    borderColor: '#4a9eff',
    backgroundColor: '#1a2a3e',
  },
  zoomOptionText: {
    fontSize: 13,
    color: '#aaa',
  },
  zoomSelectedText: {
    color: '#4a9eff',
  },
  layerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#2a2a4e',
  },
  layerName: {
    fontSize: 15,
    color: '#fff',
  },
  estimate: {
    backgroundColor: '#0f0f1a',
    borderRadius: 8,
    padding: 12,
    marginBottom: 20,
  },
  estimateRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 4,
  },
  estimateLabel: {
    fontSize: 14,
    color: '#888',
  },
  estimateValue: {
    fontSize: 14,
    color: '#fff',
    fontWeight: '500',
  },
  progressContainer: {
    marginBottom: 20,
  },
  progressBar: {
    height: 8,
    backgroundColor: '#2a2a4e',
    borderRadius: 4,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#4a9eff',
  },
  progressText: {
    fontSize: 12,
    color: '#888',
    textAlign: 'center',
    marginTop: 8,
  },
  downloadButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#4a9eff',
    borderRadius: 12,
    padding: 16,
  },
  downloadButtonDisabled: {
    opacity: 0.5,
  },
  downloadButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
    marginLeft: 8,
  },
});

export default OfflineRegionSelector;
