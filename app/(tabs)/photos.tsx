import { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Image,
  RefreshControl,
  Alert,
  Dimensions,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useFocusEffect } from '@react-navigation/native';
import { useDatabase } from '@/hooks/useDatabase';
import type { Photo, Project } from '@/types';
import { formatDate } from '@/utils';

const { width } = Dimensions.get('window');
const COLUMN_COUNT = 3;
const ITEM_SIZE = (width - 32 - (COLUMN_COUNT - 1) * 4) / COLUMN_COUNT;

export default function PhotosScreen() {
  const { photoRepository, projectRepository } = useDatabase();
  const [projects, setProjects] = useState<Project[]>([]);
  const [selectedProject, setSelectedProject] = useState<Project | null>(null);
  const [photos, setPhotos] = useState<Photo[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [selectedPhoto, setSelectedPhoto] = useState<Photo | null>(null);

  useFocusEffect(
    useCallback(() => {
      loadProjects();
    }, [projectRepository])
  );

  const loadProjects = async () => {
    if (!projectRepository) return;

    try {
      const data = await projectRepository.getAll();
      setProjects(data);

      if (data.length > 0 && !selectedProject) {
        setSelectedProject(data[0]);
      }
    } catch (error) {
      console.error('Failed to load projects:', error);
    }
  };

  useFocusEffect(
    useCallback(() => {
      if (selectedProject) {
        loadPhotos();
      }
    }, [selectedProject, photoRepository])
  );

  const loadPhotos = async () => {
    if (!photoRepository || !selectedProject) return;

    try {
      const data = await photoRepository.getByProject(selectedProject.id);
      setPhotos(data);
    } catch (error) {
      console.error('Failed to load photos:', error);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadPhotos();
    setRefreshing(false);
  };

  const handleSelectProject = () => {
    if (projects.length === 0) {
      Alert.alert('No Projects', 'Create a project first from the Dashboard');
      return;
    }

    Alert.alert(
      'Select Project',
      'Choose a project:',
      projects.map((p) => ({
        text: p.name,
        onPress: () => setSelectedProject(p),
      }))
    );
  };

  const handleOpenCamera = () => {
    Alert.alert(
      'Camera',
      'Camera functionality requires a development build.\n\nRun `npx expo prebuild` then `npx expo run:ios` to enable the camera.'
    );
  };

  const handlePhotoPress = (photo: Photo) => {
    setSelectedPhoto(photo);
  };

  const handleDeletePhoto = (photo: Photo) => {
    Alert.alert('Delete Photo', 'Are you sure you want to delete this photo?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          if (photoRepository) {
            await photoRepository.delete(photo.id);
            setPhotos((prev) => prev.filter((p) => p.id !== photo.id));
            setSelectedPhoto(null);
          }
        },
      },
    ]);
  };

  const renderPhoto = ({ item }: { item: Photo }) => (
    <TouchableOpacity
      style={styles.photoItem}
      onPress={() => handlePhotoPress(item)}
      onLongPress={() => handleDeletePhoto(item)}
    >
      <Image
        source={{ uri: item.thumbnailUri || item.uri }}
        style={styles.photoThumbnail}
        resizeMode="cover"
      />
      {item.caption && (
        <View style={styles.captionBadge}>
          <Ionicons name="text" size={10} color="#fff" />
        </View>
      )}
      {item.latitude !== null && (
        <View style={styles.locationBadge}>
          <Ionicons name="location" size={10} color="#fff" />
        </View>
      )}
    </TouchableOpacity>
  );

  // Photo detail modal
  if (selectedPhoto) {
    return (
      <View style={styles.detailContainer}>
        <TouchableOpacity style={styles.closeButton} onPress={() => setSelectedPhoto(null)}>
          <Ionicons name="close" size={28} color="#fff" />
        </TouchableOpacity>

        <Image source={{ uri: selectedPhoto.uri }} style={styles.fullPhoto} resizeMode="contain" />

        <View style={styles.photoInfo}>
          {selectedPhoto.caption && (
            <Text style={styles.photoCaption}>{selectedPhoto.caption}</Text>
          )}
          <Text style={styles.photoDate}>{formatDate(selectedPhoto.capturedAt, true)}</Text>
          {selectedPhoto.latitude !== null && (
            <Text style={styles.photoLocation}>
              {selectedPhoto.latitude.toFixed(6)}, {selectedPhoto.longitude?.toFixed(6)}
            </Text>
          )}
          {selectedPhoto.tags.length > 0 && (
            <View style={styles.tagsContainer}>
              {selectedPhoto.tags.map((tag, index) => (
                <View key={index} style={styles.tag}>
                  <Text style={styles.tagText}>{tag}</Text>
                </View>
              ))}
            </View>
          )}
        </View>

        <TouchableOpacity
          style={styles.deleteButton}
          onPress={() => handleDeletePhoto(selectedPhoto)}
        >
          <Ionicons name="trash" size={20} color="#ff6b6b" />
          <Text style={styles.deleteText}>Delete</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Project selector */}
      <TouchableOpacity style={styles.projectSelector} onPress={handleSelectProject}>
        <Ionicons name="folder" size={18} color="#4a9eff" />
        <Text style={styles.projectName}>{selectedProject?.name || 'Select Project'}</Text>
        <Ionicons name="chevron-down" size={18} color="#888" />
      </TouchableOpacity>

      {/* Photos grid */}
      <FlatList
        data={photos}
        keyExtractor={(item) => item.id}
        renderItem={renderPhoto}
        numColumns={COLUMN_COUNT}
        contentContainerStyle={styles.grid}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#4a9eff" />
        }
        ListEmptyComponent={
          <View style={styles.emptyState}>
            <Ionicons name="images-outline" size={64} color="#444" />
            <Text style={styles.emptyTitle}>No Photos Yet</Text>
            <Text style={styles.emptySubtitle}>Capture field photos with GPS metadata</Text>
          </View>
        }
      />

      {/* Camera FAB */}
      <TouchableOpacity style={styles.fab} onPress={handleOpenCamera}>
        <Ionicons name="camera" size={28} color="#fff" />
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  projectSelector: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
    marginHorizontal: 16,
    marginTop: 16,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  projectName: {
    flex: 1,
    color: '#fff',
    fontSize: 16,
    marginLeft: 8,
  },
  grid: {
    padding: 16,
    paddingBottom: 100,
  },
  photoItem: {
    width: ITEM_SIZE,
    height: ITEM_SIZE,
    margin: 2,
    borderRadius: 8,
    overflow: 'hidden',
    backgroundColor: '#1a1a2e',
  },
  photoThumbnail: {
    width: '100%',
    height: '100%',
  },
  captionBadge: {
    position: 'absolute',
    bottom: 4,
    right: 4,
    backgroundColor: 'rgba(0,0,0,0.6)',
    borderRadius: 4,
    padding: 2,
  },
  locationBadge: {
    position: 'absolute',
    bottom: 4,
    left: 4,
    backgroundColor: 'rgba(74,158,255,0.8)',
    borderRadius: 4,
    padding: 2,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
    width: width - 32,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#fff',
    marginTop: 16,
  },
  emptySubtitle: {
    fontSize: 14,
    color: '#888',
    marginTop: 8,
    textAlign: 'center',
    paddingHorizontal: 40,
  },
  fab: {
    position: 'absolute',
    right: 20,
    bottom: 20,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#4a9eff',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  // Detail view
  detailContainer: {
    flex: 1,
    backgroundColor: '#000',
  },
  closeButton: {
    position: 'absolute',
    top: 50,
    left: 16,
    zIndex: 10,
    padding: 8,
  },
  fullPhoto: {
    flex: 1,
    width: '100%',
  },
  photoInfo: {
    padding: 16,
    backgroundColor: '#1a1a2e',
  },
  photoCaption: {
    fontSize: 16,
    color: '#fff',
    marginBottom: 8,
  },
  photoDate: {
    fontSize: 13,
    color: '#888',
  },
  photoLocation: {
    fontSize: 12,
    color: '#4a9eff',
    marginTop: 4,
    fontFamily: 'monospace',
  },
  tagsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginTop: 12,
  },
  tag: {
    backgroundColor: '#2a2a4e',
    borderRadius: 4,
    paddingHorizontal: 8,
    paddingVertical: 4,
    marginRight: 6,
    marginBottom: 6,
  },
  tagText: {
    fontSize: 12,
    color: '#aaa',
  },
  deleteButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
    backgroundColor: '#1a1a2e',
    borderTopWidth: 1,
    borderTopColor: '#2a2a4e',
  },
  deleteText: {
    color: '#ff6b6b',
    fontSize: 15,
    marginLeft: 8,
  },
});
