import wave
import math
import struct

def generate_beep(duration_seconds, frequency, sample_rate=44100):
    frames = []
    for i in range(int(duration_seconds * sample_rate)):
        # Square wave for a harsh alarm sound
        t = i / sample_rate
        val = 1.0 if math.sin(2 * math.pi * frequency * t) > 0 else -1.0
        # Volume (max 32767 for 16-bit audio)
        sample = int(val * 16384)
        frames.append(struct.pack('<h', sample))
    return b''.join(frames)

# Generate a 2 second alarm (alternating between two frequencies)
sample_rate = 44100
duration = 0.5
audio_data = b''

for _ in range(3): # repeat 3 times
    audio_data += generate_beep(duration, 1200, sample_rate) # high pitch
    audio_data += generate_beep(duration, 800, sample_rate)  # lower pitch

with wave.open('scratch/route_alert.wav', 'w') as wav_file:
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(sample_rate)
    wav_file.writeframes(audio_data)

print("Audio generated successfully.")
