import { renderHook, act, waitFor } from '@testing-library/react-native';
import * as Location from 'expo-location';
import { useLocation } from '../../hooks/useLocation';

jest.mock('expo-location');

const mockLocation = {
  coords: {
    latitude: 37.7749,
    longitude: -122.4194,
    altitude: 10,
    accuracy: 5,
    heading: 90,
    speed: 1.5,
  },
  timestamp: Date.now(),
};

describe('useLocation', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (Location.getForegroundPermissionsAsync as jest.Mock).mockResolvedValue({
      status: 'granted',
    });
    (Location.requestForegroundPermissionsAsync as jest.Mock).mockResolvedValue({
      status: 'granted',
    });
    (Location.requestBackgroundPermissionsAsync as jest.Mock).mockResolvedValue({
      status: 'granted',
    });
    (Location.getCurrentPositionAsync as jest.Mock).mockResolvedValue(mockLocation);
    (Location.watchPositionAsync as jest.Mock).mockResolvedValue({
      remove: jest.fn(),
    });
  });

  describe('initialization', () => {
    it('should check permissions on mount', async () => {
      renderHook(() => useLocation());

      await waitFor(() => {
        expect(Location.getForegroundPermissionsAsync).toHaveBeenCalled();
      });
    });

    it('should set hasPermission based on status', async () => {
      (Location.getForegroundPermissionsAsync as jest.Mock).mockResolvedValue({
        status: 'granted',
      });

      const { result } = renderHook(() => useLocation());

      await waitFor(() => {
        expect(result.current.hasPermission).toBe(true);
      });
    });

    it('should auto-fetch location when permission granted', async () => {
      const { result } = renderHook(() => useLocation({ autoStart: true }));

      await waitFor(() => {
        expect(result.current.location).not.toBeNull();
      });
    });
  });

  describe('requestPermission', () => {
    it('should request foreground and background permissions', async () => {
      const { result } = renderHook(() => useLocation());

      await act(async () => {
        await result.current.requestPermission();
      });

      expect(Location.requestForegroundPermissionsAsync).toHaveBeenCalled();
      expect(Location.requestBackgroundPermissionsAsync).toHaveBeenCalled();
    });

    it('should return true when granted', async () => {
      const { result } = renderHook(() => useLocation());

      let granted: boolean = false;
      await act(async () => {
        granted = await result.current.requestPermission();
      });

      expect(granted).toBe(true);
    });

    it('should return false when denied', async () => {
      (Location.requestForegroundPermissionsAsync as jest.Mock).mockResolvedValue({
        status: 'denied',
      });

      const { result } = renderHook(() => useLocation());

      let granted: boolean = true;
      await act(async () => {
        granted = await result.current.requestPermission();
      });

      expect(granted).toBe(false);
    });
  });

  describe('getCurrentLocation', () => {
    it('should return current location', async () => {
      const { result } = renderHook(() => useLocation());

      await waitFor(() => {
        expect(result.current.hasPermission).toBe(true);
      });

      let location;
      await act(async () => {
        location = await result.current.getCurrentLocation();
      });

      expect(location).toEqual({
        latitude: 37.7749,
        longitude: -122.4194,
        altitude: 10,
        accuracy: 5,
        heading: 90,
        speed: 1.5,
        timestamp: expect.any(Number),
      });
    });

    it('should request permission if not granted', async () => {
      (Location.getForegroundPermissionsAsync as jest.Mock).mockResolvedValue({
        status: 'denied',
      });

      const { result } = renderHook(() => useLocation());

      await waitFor(() => {
        expect(result.current.hasPermission).toBe(false);
      });

      await act(async () => {
        await result.current.getCurrentLocation();
      });

      expect(Location.requestForegroundPermissionsAsync).toHaveBeenCalled();
    });

    it('should set error on failure', async () => {
      (Location.getCurrentPositionAsync as jest.Mock).mockRejectedValue(
        new Error('Location unavailable')
      );

      const { result } = renderHook(() => useLocation());

      await waitFor(() => {
        expect(result.current.hasPermission).toBe(true);
      });

      await act(async () => {
        await result.current.getCurrentLocation();
      });

      expect(result.current.error).toBe('Location unavailable');
    });
  });

  describe('tracking', () => {
    it('should start location tracking', async () => {
      const { result } = renderHook(() => useLocation());

      await waitFor(() => {
        expect(result.current.hasPermission).toBe(true);
      });

      await act(async () => {
        await result.current.startTracking();
      });

      expect(result.current.isTracking).toBe(true);
      expect(Location.watchPositionAsync).toHaveBeenCalled();
    });

    it('should stop location tracking', async () => {
      const mockRemove = jest.fn();
      (Location.watchPositionAsync as jest.Mock).mockResolvedValue({
        remove: mockRemove,
      });

      const { result } = renderHook(() => useLocation());

      await waitFor(() => {
        expect(result.current.hasPermission).toBe(true);
      });

      await act(async () => {
        await result.current.startTracking();
      });

      act(() => {
        result.current.stopTracking();
      });

      expect(result.current.isTracking).toBe(false);
      expect(mockRemove).toHaveBeenCalled();
    });

    it('should not start tracking twice', async () => {
      const { result } = renderHook(() => useLocation());

      await waitFor(() => {
        expect(result.current.hasPermission).toBe(true);
      });

      await act(async () => {
        await result.current.startTracking();
        await result.current.startTracking();
      });

      expect(Location.watchPositionAsync).toHaveBeenCalledTimes(1);
    });
  });

  describe('cleanup', () => {
    it('should remove subscription on unmount', async () => {
      const mockRemove = jest.fn();
      (Location.watchPositionAsync as jest.Mock).mockResolvedValue({
        remove: mockRemove,
      });

      const { result, unmount } = renderHook(() => useLocation());

      await waitFor(() => {
        expect(result.current.hasPermission).toBe(true);
      });

      await act(async () => {
        await result.current.startTracking();
      });

      unmount();

      expect(mockRemove).toHaveBeenCalled();
    });
  });
});
