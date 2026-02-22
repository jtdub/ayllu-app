import { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ActivityIndicator, Alert } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as FileSystem from 'expo-file-system';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import * as Sharing from 'expo-sharing';
import { useDatabase } from '@/hooks/useDatabase';
import { GeoJSONExporter } from '@/services/export/GeoJSONExporter';
import { GeoPackageExporter } from '@/services/export/GeoPackageExporter';
import type { Project, ExportFormat } from '@/types';
import { formatFileSize, generateFilename } from '@/utils';

export default function ExportScreen() {
  const { projectId } = useLocalSearchParams<{ projectId: string }>();
  const router = useRouter();
  const {
    projectRepository,
    waypointRepository,
    photoRepository,
    fieldNoteRepository,
    exportHistoryRepository,
  } = useDatabase();

  const [project, setProject] = useState<Project | null>(null);
  const [selectedFormat, setSelectedFormat] = useState<ExportFormat>('geojson');
  const [exporting, setExporting] = useState(false);
  const [stats, setStats] = useState({ waypoints: 0, photos: 0, notes: 0 });

  useEffect(() => {
    if (projectId) {
      loadProject();
    }
  }, [projectId, projectRepository]);

  const loadProject = async () => {
    if (!projectRepository || !projectId) return;

    const data = await projectRepository.getById(projectId);
    setProject(data);

    if (data) {
      const projectStats = await projectRepository.getStats(projectId);
      setStats({
        waypoints: projectStats.waypointCount,
        photos: projectStats.photoCount,
        notes: projectStats.noteCount,
      });
    }
  };

  const handleExport = async () => {
    if (!project || !waypointRepository || !photoRepository || !fieldNoteRepository) {
      return;
    }

    setExporting(true);

    try {
      // Gather data
      const waypoints = await waypointRepository.getByProject(project.id);
      const photos = await photoRepository.getByProject(project.id);
      const notes = await fieldNoteRepository.getByProject(project.id);

      let fileContent: string;
      let filename: string;
      let mimeType: string;

      switch (selectedFormat) {
        case 'geojson':
          fileContent = GeoJSONExporter.exportProject(project, waypoints, photos, notes);
          filename = generateFilename(project.name, 'geojson');
          mimeType = 'application/geo+json';
          break;

        case 'geopackage':
          // GeoPackage is more complex - for now we'll export as GeoJSON with .gpkg extension info
          fileContent = GeoPackageExporter.exportAsGeoJSON(project, waypoints, photos, notes);
          filename = generateFilename(project.name, 'json');
          mimeType = 'application/json';
          Alert.alert(
            'Note',
            'Full GeoPackage export requires desktop conversion. Exporting as JSON for now.'
          );
          break;

        case 'csv':
          fileContent = exportAsCSV(waypoints);
          filename = generateFilename(project.name, 'csv');
          mimeType = 'text/csv';
          break;

        default:
          throw new Error(`Unsupported format: ${selectedFormat}`);
      }

      // Write file
      const filePath = `${FileSystem.cacheDirectory}${filename}`;
      await FileSystem.writeAsStringAsync(filePath, fileContent, {
        encoding: FileSystem.EncodingType.UTF8,
      });

      // Get file info
      const fileInfo = await FileSystem.getInfoAsync(filePath);
      const fileSize = fileInfo.exists ? (fileInfo as { size: number }).size : 0;

      // Save to export history
      if (exportHistoryRepository) {
        await exportHistoryRepository.create({
          projectId: project.id,
          format: selectedFormat,
          filename,
          filePath,
          sizeBytes: fileSize,
          waypointCount: waypoints.length,
          photoCount: photos.length,
          noteCount: notes.length,
        });
      }

      // Share file
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(filePath, {
          mimeType,
          dialogTitle: `Export ${project.name}`,
        });
      } else {
        Alert.alert('Success', `Exported to: ${filePath}`);
      }

      router.back();
    } catch (error) {
      console.error('Export failed:', error);
      Alert.alert('Export Failed', 'An error occurred while exporting the data.');
    } finally {
      setExporting(false);
    }
  };

  const exportAsCSV = (
    waypoints: {
      name: string;
      latitude: number;
      longitude: number;
      altitude: number | null;
      timestamp: string;
    }[]
  ): string => {
    const headers = ['name', 'latitude', 'longitude', 'altitude', 'timestamp'];
    const rows = waypoints.map((wp) =>
      [`"${wp.name}"`, wp.latitude, wp.longitude, wp.altitude ?? '', wp.timestamp].join(',')
    );

    return [headers.join(','), ...rows].join('\n');
  };

  if (!project) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" color="#4a9eff" />
      </View>
    );
  }

  return (
    <>
      <Stack.Screen
        options={{
          title: 'Export Data',
          headerLeft: () => (
            <TouchableOpacity onPress={() => router.back()} style={styles.headerButton}>
              <Ionicons name="close" size={24} color="#fff" />
            </TouchableOpacity>
          ),
        }}
      />

      <View style={styles.container}>
        {/* Project Info */}
        <View style={styles.projectInfo}>
          <Text style={styles.projectName}>{project.name}</Text>
          <View style={styles.statsRow}>
            <View style={styles.stat}>
              <Text style={styles.statNumber}>{stats.waypoints}</Text>
              <Text style={styles.statLabel}>Waypoints</Text>
            </View>
            <View style={styles.stat}>
              <Text style={styles.statNumber}>{stats.photos}</Text>
              <Text style={styles.statLabel}>Photos</Text>
            </View>
            <View style={styles.stat}>
              <Text style={styles.statNumber}>{stats.notes}</Text>
              <Text style={styles.statLabel}>Notes</Text>
            </View>
          </View>
        </View>

        {/* Format Selection */}
        <Text style={styles.sectionTitle}>Export Format</Text>

        <TouchableOpacity
          style={[styles.formatOption, selectedFormat === 'geojson' && styles.selectedFormat]}
          onPress={() => setSelectedFormat('geojson')}
        >
          <View style={styles.formatIcon}>
            <Ionicons name="globe" size={24} color="#4a9eff" />
          </View>
          <View style={styles.formatInfo}>
            <Text style={styles.formatTitle}>GeoJSON</Text>
            <Text style={styles.formatDescription}>
              Standard format for GIS applications. Opens in QGIS, Mapbox, etc.
            </Text>
          </View>
          {selectedFormat === 'geojson' && (
            <Ionicons name="checkmark-circle" size={24} color="#4a9eff" />
          )}
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.formatOption, selectedFormat === 'geopackage' && styles.selectedFormat]}
          onPress={() => setSelectedFormat('geopackage')}
        >
          <View style={styles.formatIcon}>
            <Ionicons name="cube" size={24} color="#4a9eff" />
          </View>
          <View style={styles.formatInfo}>
            <Text style={styles.formatTitle}>GeoPackage (JSON)</Text>
            <Text style={styles.formatDescription}>
              SQLite-based format. Full conversion available via MCP server.
            </Text>
          </View>
          {selectedFormat === 'geopackage' && (
            <Ionicons name="checkmark-circle" size={24} color="#4a9eff" />
          )}
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.formatOption, selectedFormat === 'csv' && styles.selectedFormat]}
          onPress={() => setSelectedFormat('csv')}
        >
          <View style={styles.formatIcon}>
            <Ionicons name="grid" size={24} color="#4a9eff" />
          </View>
          <View style={styles.formatInfo}>
            <Text style={styles.formatTitle}>CSV</Text>
            <Text style={styles.formatDescription}>Simple spreadsheet format. Waypoints only.</Text>
          </View>
          {selectedFormat === 'csv' && (
            <Ionicons name="checkmark-circle" size={24} color="#4a9eff" />
          )}
        </TouchableOpacity>

        {/* Export Button */}
        <TouchableOpacity
          style={[styles.exportButton, exporting && styles.exportingButton]}
          onPress={handleExport}
          disabled={exporting}
        >
          {exporting ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <>
              <Ionicons name="download" size={20} color="#fff" />
              <Text style={styles.exportButtonText}>Export & Share</Text>
            </>
          )}
        </TouchableOpacity>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
    padding: 16,
  },
  centerContainer: {
    flex: 1,
    backgroundColor: '#0f0f1a',
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerButton: {
    padding: 8,
  },
  projectInfo: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    marginBottom: 24,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  projectName: {
    fontSize: 20,
    fontWeight: '600',
    color: '#fff',
    marginBottom: 12,
  },
  statsRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  stat: {
    alignItems: 'center',
  },
  statNumber: {
    fontSize: 24,
    fontWeight: '700',
    color: '#4a9eff',
  },
  statLabel: {
    fontSize: 12,
    color: '#888',
    marginTop: 4,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 12,
  },
  formatOption: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  selectedFormat: {
    borderColor: '#4a9eff',
    backgroundColor: '#1a2a3e',
  },
  formatIcon: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#0f0f1a',
    alignItems: 'center',
    justifyContent: 'center',
  },
  formatInfo: {
    flex: 1,
    marginLeft: 12,
  },
  formatTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
  },
  formatDescription: {
    fontSize: 13,
    color: '#888',
    marginTop: 2,
  },
  exportButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#4a9eff',
    borderRadius: 12,
    padding: 16,
    marginTop: 24,
  },
  exportingButton: {
    opacity: 0.7,
  },
  exportButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
    marginLeft: 8,
  },
});
