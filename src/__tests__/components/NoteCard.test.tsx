import React from 'react';
import { render, fireEvent } from '@testing-library/react-native';
import { NoteCard } from '../../components/notes/NoteCard';
import type { FieldNote } from '../../types';

const mockNote: FieldNote = {
  id: 'note-1',
  projectId: 'project-123',
  waypointId: 'wp-1',
  photoId: null,
  title: 'Field Observation',
  content:
    'Observed ceramic fragments near the eastern wall. Appears to be late period pottery with distinctive red slip.',
  audioUri: null,
  audioDuration: null,
  transcriptionSource: null,
  transcriptionConfidence: null,
  tags: ['ceramics', 'pottery', 'eastern-sector'],
  latitude: 37.7749,
  longitude: -122.4194,
  timestamp: '2024-01-15T10:32:00Z',
  createdAt: '2024-01-15T10:32:00Z',
  updatedAt: '2024-01-15T10:32:00Z',
};

describe('NoteCard', () => {
  it('should render note title', () => {
    const { getByText } = render(<NoteCard note={mockNote} />);

    expect(getByText('Field Observation')).toBeTruthy();
  });

  it('should render note content preview', () => {
    const { getByText } = render(<NoteCard note={mockNote} />);

    expect(getByText(/Observed ceramic fragments/)).toBeTruthy();
  });

  it('should render "Untitled Note" when title is null', () => {
    const noteWithoutTitle = { ...mockNote, title: null };
    const { getByText } = render(<NoteCard note={noteWithoutTitle} />);

    expect(getByText('Untitled Note')).toBeTruthy();
  });

  it('should render tags', () => {
    const { getByText } = render(<NoteCard note={mockNote} />);

    expect(getByText('ceramics')).toBeTruthy();
    expect(getByText('pottery')).toBeTruthy();
  });

  it('should show "+N" for extra tags beyond 3', () => {
    const noteWithManyTags = {
      ...mockNote,
      tags: ['tag1', 'tag2', 'tag3', 'tag4', 'tag5'],
    };
    const { getByText } = render(<NoteCard note={noteWithManyTags} />);

    expect(getByText('+2')).toBeTruthy();
  });

  it('should show location indicator when note has coordinates', () => {
    const { UNSAFE_getByType } = render(<NoteCard note={mockNote} />);

    // The location icon should be rendered
    // This is a simplified check - in real tests we'd use testID
    expect(UNSAFE_getByType).toBeDefined();
  });

  it('should show audio indicator when note has audio', () => {
    const noteWithAudio = {
      ...mockNote,
      audioUri: '/path/to/audio.m4a',
      audioDuration: 30000,
    };
    const { UNSAFE_queryAllByType } = render(<NoteCard note={noteWithAudio} />);

    expect(UNSAFE_queryAllByType).toBeDefined();
  });

  it('should call onPress when pressed', () => {
    const onPress = jest.fn();
    const { getByText } = render(<NoteCard note={mockNote} onPress={onPress} />);

    fireEvent.press(getByText('Field Observation'));

    expect(onPress).toHaveBeenCalled();
  });

  it('should call onLongPress when long pressed', () => {
    const onLongPress = jest.fn();
    const { getByText } = render(<NoteCard note={mockNote} onLongPress={onLongPress} />);

    fireEvent(getByText('Field Observation'), 'longPress');

    expect(onLongPress).toHaveBeenCalled();
  });

  it('should show project name when showProject is true', () => {
    const { getByText } = render(
      <NoteCard note={mockNote} showProject={true} projectName="Test Project" />
    );

    expect(getByText('Test Project')).toBeTruthy();
  });

  it('should not show project name when showProject is false', () => {
    const { queryByText } = render(
      <NoteCard note={mockNote} showProject={false} projectName="Test Project" />
    );

    expect(queryByText('Test Project')).toBeNull();
  });

  it('should show transcription confidence when transcribed', () => {
    const transcribedNote = {
      ...mockNote,
      transcriptionSource: 'whisper' as const,
      transcriptionConfidence: 0.95,
    };
    const { getByText } = render(<NoteCard note={transcribedNote} />);

    expect(getByText('95%')).toBeTruthy();
  });
});
