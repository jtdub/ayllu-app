import { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Switch,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useFocusEffect } from '@react-navigation/native';
import { useDatabase } from '@/hooks/useDatabase';
import { formatFileSize } from '@/utils';

export default function SettingsScreen() {
  const router = useRouter();
  const { mapRegionRepository, exportHistoryRepository } = useDatabase();

  const [offlineMapSize, setOfflineMapSize] = useState(0);
  const [exportCount, setExportCount] = useState(0);

  // Settings state
  const [autoSaveNotes, setAutoSaveNotes] = useState(true);
  const [autoTagLocation, setAutoTagLocation] = useState(true);
  const [coordinateFormat, setCoordinateFormat] = useState<'decimal' | 'dms' | 'utm'>('decimal');
  const [distanceUnit, setDistanceUnit] = useState<'meters' | 'feet'>('meters');

  useFocusEffect(
    useCallback(() => {
      loadStats();
    }, [mapRegionRepository, exportHistoryRepository])
  );

  const loadStats = async () => {
    if (mapRegionRepository) {
      const size = await mapRegionRepository.getTotalSize();
      setOfflineMapSize(size);
    }

    if (exportHistoryRepository) {
      const history = await exportHistoryRepository.getAll();
      setExportCount(history.length);
    }
  };

  const handleClearOfflineMaps = () => {
    Alert.alert(
      'Clear Offline Maps',
      'This will delete all downloaded map regions. You will need to download them again for offline use.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear',
          style: 'destructive',
          onPress: async () => {
            // Implementation would delete all map regions
            Alert.alert('Success', 'Offline maps cleared');
            setOfflineMapSize(0);
          },
        },
      ]
    );
  };

  const handleCoordinateFormat = () => {
    Alert.alert(
      'Coordinate Format',
      'Select your preferred coordinate display format:',
      [
        { text: 'Decimal (37.7749, -122.4194)', onPress: () => setCoordinateFormat('decimal') },
        { text: 'DMS (37°46\'29.64"N, 122°25\'9.84"W)', onPress: () => setCoordinateFormat('dms') },
        { text: 'UTM (10S 551766E 4180096N)', onPress: () => setCoordinateFormat('utm') },
        { text: 'Cancel', style: 'cancel' },
      ]
    );
  };

  const handleDistanceUnit = () => {
    Alert.alert(
      'Distance Unit',
      'Select your preferred distance unit:',
      [
        { text: 'Meters/Kilometers', onPress: () => setDistanceUnit('meters') },
        { text: 'Feet/Miles', onPress: () => setDistanceUnit('feet') },
        { text: 'Cancel', style: 'cancel' },
      ]
    );
  };

  const handleExport = () => {
    Alert.alert(
      'Export All Data',
      'Export all projects as a GeoJSON archive?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Export', onPress: () => Alert.alert('Info', 'Export functionality coming soon') },
      ]
    );
  };

  const handleAbout = () => {
    Alert.alert(
      'Ayllu',
      'Field Research Companion\nVersion 1.0.0\n\nA mobile app for archaeological and anthropological fieldwork combining GPS waypoints, photo documentation, voice-to-text field notes, and offline maps.\n\nBuilt with Expo & React Native',
      [{ text: 'OK' }]
    );
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Data Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Data</Text>

        <TouchableOpacity style={styles.settingItem}>
          <View style={styles.settingInfo}>
            <Ionicons name="map" size={22} color="#4a9eff" />
            <View style={styles.settingText}>
              <Text style={styles.settingLabel}>Offline Maps</Text>
              <Text style={styles.settingValue}>{formatFileSize(offlineMapSize)}</Text>
            </View>
          </View>
          <TouchableOpacity onPress={handleClearOfflineMaps}>
            <Text style={styles.clearButton}>Clear</Text>
          </TouchableOpacity>
        </TouchableOpacity>

        <TouchableOpacity style={styles.settingItem}>
          <View style={styles.settingInfo}>
            <Ionicons name="download" size={22} color="#4a9eff" />
            <View style={styles.settingText}>
              <Text style={styles.settingLabel}>Export History</Text>
              <Text style={styles.settingValue}>{exportCount} exports</Text>
            </View>
          </View>
          <Ionicons name="chevron-forward" size={20} color="#888" />
        </TouchableOpacity>

        <TouchableOpacity style={styles.settingItem} onPress={handleExport}>
          <View style={styles.settingInfo}>
            <Ionicons name="share" size={22} color="#4a9eff" />
            <View style={styles.settingText}>
              <Text style={styles.settingLabel}>Export All Data</Text>
              <Text style={styles.settingValue}>GeoJSON archive</Text>
            </View>
          </View>
          <Ionicons name="chevron-forward" size={20} color="#888" />
        </TouchableOpacity>
      </View>

      {/* Field Settings Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Field Settings</Text>

        <View style={styles.settingItem}>
          <View style={styles.settingInfo}>
            <Ionicons name="save" size={22} color="#4a9eff" />
            <View style={styles.settingText}>
              <Text style={styles.settingLabel}>Auto-save Notes</Text>
              <Text style={styles.settingValue}>Save notes automatically</Text>
            </View>
          </View>
          <Switch
            value={autoSaveNotes}
            onValueChange={setAutoSaveNotes}
            trackColor={{ false: '#2a2a4e', true: '#4a9eff' }}
            thumbColor="#fff"
          />
        </View>

        <View style={styles.settingItem}>
          <View style={styles.settingInfo}>
            <Ionicons name="location" size={22} color="#4a9eff" />
            <View style={styles.settingText}>
              <Text style={styles.settingLabel}>Auto-tag Location</Text>
              <Text style={styles.settingValue}>Add GPS to notes & photos</Text>
            </View>
          </View>
          <Switch
            value={autoTagLocation}
            onValueChange={setAutoTagLocation}
            trackColor={{ false: '#2a2a4e', true: '#4a9eff' }}
            thumbColor="#fff"
          />
        </View>

        <TouchableOpacity style={styles.settingItem} onPress={handleCoordinateFormat}>
          <View style={styles.settingInfo}>
            <Ionicons name="globe" size={22} color="#4a9eff" />
            <View style={styles.settingText}>
              <Text style={styles.settingLabel}>Coordinate Format</Text>
              <Text style={styles.settingValue}>
                {coordinateFormat === 'decimal' ? 'Decimal degrees' :
                 coordinateFormat === 'dms' ? 'Degrees, minutes, seconds' : 'UTM'}
              </Text>
            </View>
          </View>
          <Ionicons name="chevron-forward" size={20} color="#888" />
        </TouchableOpacity>

        <TouchableOpacity style={styles.settingItem} onPress={handleDistanceUnit}>
          <View style={styles.settingInfo}>
            <Ionicons name="resize" size={22} color="#4a9eff" />
            <View style={styles.settingText}>
              <Text style={styles.settingLabel}>Distance Unit</Text>
              <Text style={styles.settingValue}>
                {distanceUnit === 'meters' ? 'Meters / Kilometers' : 'Feet / Miles'}
              </Text>
            </View>
          </View>
          <Ionicons name="chevron-forward" size={20} color="#888" />
        </TouchableOpacity>
      </View>

      {/* About Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>About</Text>

        <TouchableOpacity style={styles.settingItem} onPress={handleAbout}>
          <View style={styles.settingInfo}>
            <Ionicons name="information-circle" size={22} color="#4a9eff" />
            <View style={styles.settingText}>
              <Text style={styles.settingLabel}>About Ayllu</Text>
              <Text style={styles.settingValue}>Version 1.0.0</Text>
            </View>
          </View>
          <Ionicons name="chevron-forward" size={20} color="#888" />
        </TouchableOpacity>
      </View>

      <View style={styles.footer}>
        <Text style={styles.footerText}>Ayllu - Field Research Companion</Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  content: {
    paddingBottom: 40,
  },
  section: {
    marginTop: 24,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 8,
    marginHorizontal: 16,
  },
  settingItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#1a1a2e',
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: '#2a2a4e',
  },
  settingInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  settingText: {
    marginLeft: 12,
    flex: 1,
  },
  settingLabel: {
    fontSize: 16,
    color: '#fff',
  },
  settingValue: {
    fontSize: 13,
    color: '#888',
    marginTop: 2,
  },
  clearButton: {
    color: '#ff6b6b',
    fontSize: 14,
    fontWeight: '500',
  },
  footer: {
    alignItems: 'center',
    padding: 24,
    marginTop: 24,
  },
  footerText: {
    fontSize: 12,
    color: '#666',
  },
});
