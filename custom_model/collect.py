"""
SignSpeak — Gesture Data Collector (MediaPipe Tasks API)
=========================================================
Compatible with mediapipe 0.10.13+

Usage:
    pip install mediapipe opencv-python numpy
    python collect.py

Controls:
    SPACE  — record current frame
    N      — next sign
    Q      — quit and save
"""

import cv2
import numpy as np
import csv
import os
import time
import urllib.request

import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision as mp_vision
from mediapipe.tasks.python.vision import HandLandmarkerOptions, HandLandmarker

# ── Signs to collect ──────────────────────────────────────────────────────────
SIGNS = [
    'none',
    'welcome',
    'build',
    'ai',
    'my',
    'name',
    'noor',
    'this',
    'sign_speak',
    'hello',
    'please',
    'thank_you',
    'yes',
    'no',
    'help',
    'what',
    'where',
    'water',
    'food',
    'stop',
    'i_love_you',
]

SAMPLES_PER_SIGN = 150
OUTPUT_DIR = 'data'
CSV_FILE   = os.path.join(OUTPUT_DIR, 'landmarks.csv')
LABEL_FILE = os.path.join(OUTPUT_DIR, 'labels.txt')
MODEL_PATH = 'hand_landmarker.task'

os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── Download model if needed ──────────────────────────────────────────────────
if not os.path.exists(MODEL_PATH):
    print("Downloading hand_landmarker.task (~29MB)...")
    url = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
    urllib.request.urlretrieve(url, MODEL_PATH)
    print("Downloaded.")

# ── MediaPipe Tasks setup ─────────────────────────────────────────────────────
latest_result = None

def result_callback(result, output_image, timestamp_ms):
    global latest_result
    latest_result = result

options = HandLandmarkerOptions(
    base_options=mp_python.BaseOptions(model_asset_path=MODEL_PATH),
    running_mode=mp_vision.RunningMode.LIVE_STREAM,
    num_hands=1,
    min_hand_detection_confidence=0.5,
    min_hand_presence_confidence=0.5,
    min_tracking_confidence=0.5,
    result_callback=result_callback,
)
landmarker = HandLandmarker.create_from_options(options)

# ── Feature extraction ────────────────────────────────────────────────────────
def extract_landmarks(result):
    if not result or not result.hand_landmarks:
        return None

    lm = result.hand_landmarks[0]  # first hand
    wrist = np.array([lm[0].x, lm[0].y, lm[0].z])
    mid_mcp = np.array([lm[9].x, lm[9].y, lm[9].z])
    span = np.linalg.norm(mid_mcp - wrist) + 1e-6

    coords = []
    for point in lm:
        coords.extend([
            (point.x - wrist[0]) / span,
            (point.y - wrist[1]) / span,
            (point.z - wrist[2]) / span,
        ])
    return coords

def draw_landmarks(frame, result):
    if not result or not result.hand_landmarks:
        return
    h, w = frame.shape[:2]
    for hand in result.hand_landmarks:
        # Draw connections
        connections = mp.solutions.hands.HAND_CONNECTIONS if hasattr(mp, 'solutions') else [
            (0,1),(1,2),(2,3),(3,4),
            (0,5),(5,6),(6,7),(7,8),
            (0,9),(9,10),(10,11),(11,12),
            (0,13),(13,14),(14,15),(15,16),
            (0,17),(17,18),(18,19),(19,20),
            (5,9),(9,13),(13,17),
        ]
        pts = [(int(lm.x * w), int(lm.y * h)) for lm in hand]
        for a, b in connections:
            cv2.line(frame, pts[a], pts[b], (0, 200, 100), 2)
        for pt in pts:
            cv2.circle(frame, pt, 4, (0, 255, 150), -1)
            cv2.circle(frame, pt, 4, (0, 0, 0), 1)

# ── Main loop ─────────────────────────────────────────────────────────────────
def main():
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    all_rows = []
    sign_idx = 0
    count    = 0
    ts       = 0

    print(f"\n{'='*50}")
    print(f"SignSpeak Data Collector")
    print(f"Signs: {SIGNS}")
    print(f"Samples per sign: {SAMPLES_PER_SIGN}")
    print(f"SPACE=record  N=next  Q=quit")
    print(f"{'='*50}\n")

    while True:
        if sign_idx >= len(SIGNS):
            print("✓ All signs collected!")
            break

        sign = SIGNS[sign_idx]
        ret, frame = cap.read()
        if not ret:
            break

        frame = cv2.flip(frame, 1)
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        # Feed to MediaPipe Tasks
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        ts += 33
        landmarker.detect_async(mp_image, ts)

        # Draw skeleton from latest result
        draw_landmarks(frame, latest_result)

        # HUD
        cv2.rectangle(frame, (0, 0), (640, 70), (15, 15, 25), -1)
        cv2.putText(frame, f"Sign: {sign.upper()}  ({count}/{SAMPLES_PER_SIGN})",
                    (12, 38), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (50, 255, 160), 2)
        cv2.putText(frame, "SPACE=record  N=next  Q=quit",
                    (12, 62), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (150, 150, 150), 1)

        # Progress bar
        bar = int((count / SAMPLES_PER_SIGN) * 616)
        cv2.rectangle(frame, (12, 72), (628, 80), (40, 40, 40), -1)
        cv2.rectangle(frame, (12, 72), (12 + bar, 80), (50, 255, 160), -1)

        # Hand detected indicator
        hand_detected = latest_result and latest_result.hand_landmarks
        color = (0, 255, 100) if hand_detected else (0, 50, 200)
        cv2.circle(frame, (620, 30), 10, color, -1)

        cv2.imshow('SignSpeak Collector', frame)
        key = cv2.waitKey(1) & 0xFF

        if key == ord('q'):
            break
        elif key == ord('n'):
            print(f"  ✓ {sign}: {count} samples")
            sign_idx += 1
            count = 0
        elif key == ord(' '):
            coords = extract_landmarks(latest_result)
            if coords is not None:
                all_rows.append([sign_idx] + coords)
                count += 1
                print(f"  [{sign}] {count}/{SAMPLES_PER_SIGN}", end='\r')
                if count >= SAMPLES_PER_SIGN:
                    print(f"\n  ✓ {sign}: done! Press N for next.")
            else:
                print("  ✗ No hand detected — move hand into frame", end='\r')

    cap.release()
    cv2.destroyAllWindows()
    landmarker.close()

    if all_rows:
        with open(CSV_FILE, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['label'] + [f'f{i}' for i in range(63)])
            writer.writerows(all_rows)
        print(f"\n✓ Saved {len(all_rows)} samples → {CSV_FILE}")

    with open(LABEL_FILE, 'w') as f:
        f.write('\n'.join(SIGNS))
    print(f"✓ Labels → {LABEL_FILE}")
    print(f"\nNext: python train.py")

if __name__ == '__main__':
    main()