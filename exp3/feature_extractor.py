"""
EEG Feature Extractor for Comprehensive Feature Set
Based on the formulas from the research papers:
- Attention: Ec = β / (α + θ)
- Relaxation: alphaRatio = palpha / (ptheta + palpha + pbeta)
Plus additional statistical and frequency domain features
"""

import numpy as np
from scipy.fft import fft, fftfreq
from scipy.signal import butter, filtfilt
from scipy.stats import skew, kurtosis
import warnings
warnings.filterwarnings('ignore')

class EEGFeatureExtractor:
    """EEG Feature Extractor for attention and relaxation calculation"""
    
    def __init__(self, sampling_rate=500):
        """
        Initialize the feature extractor
        
        Args:
            sampling_rate (int): Sampling rate of the EEG signal (Hz)
        """
        self.sampling_rate = sampling_rate
        
        # Define frequency bands (Hz)
        self.freq_bands = {
            'delta': (0.5, 4),      # Delta waves
            'theta': (4, 8),        # Theta waves  
            'alpha': (8, 13),       # Alpha waves
            'beta': (13, 30),       # Beta waves
            'gamma': (30, 50)       # Gamma waves
        }
    
    def _butter_bandpass_filter(self, data, lowcut, highcut, order=4):
        """Apply Butterworth bandpass filter"""
        nyquist = 0.5 * self.sampling_rate
        low = lowcut / nyquist
        high = highcut / nyquist
        b, a = butter(order, [low, high], btype='band')
        return filtfilt(b, a, data)
    
    def _calculate_band_power(self, signal, freq_band):
        """Calculate power in a specific frequency band"""
        # Apply bandpass filter
        filtered_signal = self._butter_bandpass_filter(signal, freq_band[0], freq_band[1])
        
        # Calculate power using FFT
        fft_values = fft(filtered_signal)
        power_spectrum = np.abs(fft_values) ** 2
        
        # Get frequency bins
        freqs = fftfreq(len(signal), 1/self.sampling_rate)
        
        # Find indices for the frequency band
        band_mask = (freqs >= freq_band[0]) & (freqs <= freq_band[1])
        
        # Calculate total power in the band
        band_power = np.sum(power_spectrum[band_mask])
        
        return band_power
    
    def extract_attention_feature(self, signal):
        """
        Calculate attention level using the formula: Ec = β / (α + θ)
        
        Args:
            signal (np.array): EEG signal segment
            
        Returns:
            float: Attention level (Ec)
        """
        try:
            # Calculate power in each frequency band
            alpha_power = self._calculate_band_power(signal, self.freq_bands['alpha'])
            beta_power = self._calculate_band_power(signal, self.freq_bands['beta'])
            theta_power = self._calculate_band_power(signal, self.freq_bands['theta'])
            
            # Calculate attention: Ec = β / (α + θ)
            denominator = alpha_power + theta_power
            if denominator == 0:
                return 0.0  # Avoid division by zero
            
            attention = beta_power / denominator
            return attention
            
        except Exception as e:
            print(f"Error calculating attention feature: {e}")
            return 0.0
    
    def extract_relaxation_feature(self, signal):
        """
        Calculate relaxation level using the formula: 
        alphaRatio = palpha / (ptheta + palpha + pbeta)
        
        Args:
            signal (np.array): EEG signal segment
            
        Returns:
            float: Relaxation level (alphaRatio)
        """
        try:
            # Calculate power in each frequency band
            alpha_power = self._calculate_band_power(signal, self.freq_bands['alpha'])
            beta_power = self._calculate_band_power(signal, self.freq_bands['beta'])
            theta_power = self._calculate_band_power(signal, self.freq_bands['theta'])
            
            # Calculate relaxation: alphaRatio = palpha / (ptheta + palpha + pbeta)
            total_power = theta_power + alpha_power + beta_power
            if total_power == 0:
                return 0.0  # Avoid division by zero
            
            relaxation = alpha_power / total_power
            return relaxation
            
        except Exception as e:
            print(f"Error calculating relaxation feature: {e}")
            return 0.0
    
    #======add =======
    def extract_statistical_features(self, signal):
        """
        Extract statistical features from the signal
        
        Args:
            signal (np.array): EEG signal segment
            
        Returns:
            dict: Dictionary containing statistical features
        """
        try:
            features = {
                'mean': np.mean(signal),
                'std': np.std(signal),
                'var': np.var(signal),
                'skewness': skew(signal),
                'kurtosis': kurtosis(signal),
                'rms': np.sqrt(np.mean(signal**2)),
                'peak_to_peak': np.max(signal) - np.min(signal),
                'zero_crossing_rate': np.sum(np.diff(np.signbit(signal))),
                'energy': np.sum(signal**2),
                'power': np.mean(signal**2)
            }
            return features
        except Exception as e:
            print(f"Error calculating statistical features: {e}")
            return {key: 0.0 for key in ['mean', 'std', 'var', 'skewness', 'kurtosis', 
                                        'rms', 'peak_to_peak', 'zero_crossing_rate', 'energy', 'power']}
    
    def extract_frequency_features(self, signal):
        """
        Extract frequency domain features
        
        Args:
            signal (np.array): EEG signal segment
            
        Returns:
            dict: Dictionary containing frequency features
        """
        try:
            # Calculate FFT
            fft_values = fft(signal)
            power_spectrum = np.abs(fft_values) ** 2
            freqs = fftfreq(len(signal), 1/self.sampling_rate)
            
            # Only use positive frequencies
            positive_freqs = freqs[:len(freqs)//2]
            positive_power = power_spectrum[:len(power_spectrum)//2]
            
            # Spectral centroid
            spectral_centroid = np.sum(positive_freqs * positive_power) / np.sum(positive_power)
            
            # Spectral rolloff (95% of energy)
            cumulative_power = np.cumsum(positive_power)
            total_power = cumulative_power[-1]
            rolloff_idx = np.where(cumulative_power >= 0.95 * total_power)[0]
            spectral_rolloff = positive_freqs[rolloff_idx[0]] if len(rolloff_idx) > 0 else positive_freqs[-1]
            
            # Spectral bandwidth
            spectral_bandwidth = np.sqrt(np.sum(((positive_freqs - spectral_centroid) ** 2) * positive_power) / np.sum(positive_power))
            
            # Spectral flatness
            geometric_mean = np.exp(np.mean(np.log(positive_power + 1e-10)))
            arithmetic_mean = np.mean(positive_power)
            spectral_flatness = geometric_mean / arithmetic_mean if arithmetic_mean > 0 else 0
            
            features = {
                'spectral_centroid': spectral_centroid,
                'spectral_rolloff': spectral_rolloff,
                'spectral_bandwidth': spectral_bandwidth,
                'spectral_flatness': spectral_flatness
            }
            return features
        except Exception as e:
            print(f"Error calculating frequency features: {e}")
            return {key: 0.0 for key in ['spectral_centroid', 'spectral_rolloff', 'spectral_bandwidth', 'spectral_flatness']}
    
    def extract_band_ratios(self, signal):
        """
        Extract band power ratios
        
        Args:
            signal (np.array): EEG signal segment
            
        Returns:
            dict: Dictionary containing band ratios
        """
        try:
            band_powers = self.extract_band_powers(signal)
            
            # Calculate ratios
            total_power = sum(band_powers.values())
            if total_power == 0:
                return {key: 0.0 for key in ['delta_ratio', 'theta_ratio', 'alpha_ratio', 'beta_ratio', 'gamma_ratio',
                                           'beta_alpha_ratio', 'theta_alpha_ratio', 'beta_theta_ratio']}
            
            features = {
                'delta_ratio': band_powers['delta'] / total_power,
                'theta_ratio': band_powers['theta'] / total_power,
                'alpha_ratio': band_powers['alpha'] / total_power,
                'beta_ratio': band_powers['beta'] / total_power,
                'gamma_ratio': band_powers['gamma'] / total_power,
                'beta_alpha_ratio': band_powers['beta'] / band_powers['alpha'] if band_powers['alpha'] > 0 else 0,
                'theta_alpha_ratio': band_powers['theta'] / band_powers['alpha'] if band_powers['alpha'] > 0 else 0,
                'beta_theta_ratio': band_powers['beta'] / band_powers['theta'] if band_powers['theta'] > 0 else 0
            }
            return features
        except Exception as e:
            print(f"Error calculating band ratios: {e}")
            return {key: 0.0 for key in ['delta_ratio', 'theta_ratio', 'alpha_ratio', 'beta_ratio', 'gamma_ratio',
                                        'beta_alpha_ratio', 'theta_alpha_ratio', 'beta_theta_ratio']}
    #======add =======
    
    def extract_all_features(self, signal):
        """
        Extract comprehensive feature set
        
        Args:
            signal (np.array): EEG signal segment
            
        Returns:
            dict: Dictionary containing all features
        """
        # Original attention and relaxation features
        attention = self.extract_attention_feature(signal)
        relaxation = self.extract_relaxation_feature(signal)
        
        # Statistical features
        stat_features = self.extract_statistical_features(signal)
        
        # Frequency features
        freq_features = self.extract_frequency_features(signal)
        
        # Band ratio features
        ratio_features = self.extract_band_ratios(signal)
        
        # Combine all features
        all_features = {
            'attention': attention,
            'relaxation': relaxation,
            **stat_features,
            **freq_features,
            **ratio_features
        }
        
        return all_features
    
    def extract_band_powers(self, signal):
        """
        Extract power in all frequency bands
        
        Args:
            signal (np.array): EEG signal segment
            
        Returns:
            dict: Dictionary containing power in each frequency band
        """
        band_powers = {}
        for band_name, freq_range in self.freq_bands.items():
            band_powers[band_name] = self._calculate_band_power(signal, freq_range)
        
        return band_powers

def load_eeg_data_with_features(dataset_path, segment_length=5, sampling_rate=500):
    """
    Load EEG data and extract features for all subjects
    
    Args:
        dataset_path (str): Path to the dataset directory
        segment_length (int): Length of each segment in seconds
        sampling_rate (int): Sampling rate of the EEG signal
        
    Returns:
        tuple: (features, labels, subjects)
    """
    import os
    import glob
    
    # Initialize feature extractor
    extractor = EEGFeatureExtractor(sampling_rate)
    
    all_features = []
    all_labels = []
    all_subjects = []
    
    # Find all subject folders
    subject_folders = sorted(glob.glob(os.path.join(dataset_path, "S*")))
    
    if not subject_folders:
        print(f"Error: No subject folders found in {dataset_path}")
        return None, None, None
    
    segment_length_samples = int(segment_length * sampling_rate)
    
    for subject_folder in subject_folders:
        subject_id = os.path.basename(subject_folder)
        print(f"Processing {subject_id}...")
        
        # Load data
        relax_file = os.path.join(subject_folder, "1.txt")
        focus_file = os.path.join(subject_folder, "2.txt")
        
        try:
            relax_data = np.loadtxt(relax_file)
            focus_data = np.loadtxt(focus_file)
        except Exception as e:
            print(f"Error loading data for {subject_id}: {e}")
            continue
        
        # Process relax data
        relax_features = []
        for i in range(0, len(relax_data) - segment_length_samples + 1, segment_length_samples):
            segment = relax_data[i:i + segment_length_samples]
            features = extractor.extract_all_features(segment)
            # Convert to array with all features
            feature_array = [features[key] for key in sorted(features.keys())]
            relax_features.append(feature_array)
        
        # Process focus data
        focus_features = []
        for i in range(0, len(focus_data) - segment_length_samples + 1, segment_length_samples):
            segment = focus_data[i:i + segment_length_samples]
            features = extractor.extract_all_features(segment)
            # Convert to array with all features
            feature_array = [features[key] for key in sorted(features.keys())]
            focus_features.append(feature_array)
        
        if not relax_features or not focus_features:
            print(f"Warning: Not enough data to create segments for {subject_id}. Skipping this subject.")
            continue
        
        # Create labels
        relax_labels = np.zeros(len(relax_features))  # 0 = relax
        focus_labels = np.ones(len(focus_features))   # 1 = focus
        
        # Combine data
        subject_features = np.vstack([relax_features, focus_features])
        subject_labels = np.hstack([relax_labels, focus_labels])
        
        # Record subject IDs
        subject_ids = [subject_id] * len(subject_labels)
        
        all_features.append(subject_features)
        all_labels.append(subject_labels)
        all_subjects.extend(subject_ids)
    
    if not all_features:
        print("Error: No valid data found")
        return None, None, None
    
    # Combine all data
    X = np.vstack(all_features)
    y = np.hstack(all_labels)
    
    print(f"Total features extracted: {X.shape[0]}")
    print(f"Feature dimensions: {X.shape[1]} (comprehensive feature set)")
    
    # Print feature names
    if X.shape[0] > 0:
        sample_features = extractor.extract_all_features(np.random.randn(segment_length_samples))
        feature_names = sorted(sample_features.keys())
        print(f"Feature names: {feature_names}")
    
    return X, y, all_subjects

