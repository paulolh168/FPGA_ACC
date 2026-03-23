import serial
import cv2
import numpy as np
import time
import os
import threading

# ==========================================
# 1. 환경 설정
# ==========================================
PORT = 'COM4'
BAUD_RATE = 921600
VIDEO_INPUT = 'test_video.avi'  # 원본 영상 파일명
# 바탕화면 경로 설정
DESKTOP_PATH = os.path.join(os.path.expanduser("~"), "Desktop", "output_edge.mp4")

# FPGA 설정 (Model.v의 IMG_WIDTH와 반드시 일치해야 함!)
FPGA_WIDTH = 384 

# 수신용 공유 변수
received_frame_data = bytearray()
receive_done = threading.Event()

def receive_thread(ser, total_bytes):
    """한 프레임 분량의 데이터를 다 받을 때까지 대기하는 스레드"""
    global received_frame_data
    while len(received_frame_data) < total_bytes:
        waiting = ser.in_waiting
        if waiting > 0:
            chunk = ser.read(waiting)
            received_frame_data.extend(chunk)
    receive_done.set()

def main():
    # 2. 동영상 파일 열기
    cap = cv2.VideoCapture(VIDEO_INPUT)
    if not cap.isOpened():
        print(f"❌ 영상을 열 수 없다: {VIDEO_INPUT}")
        return

    # 영상 정보 획득
    fps = cap.get(cv2.CAP_PROP_FPS)
    orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    
    # FPGA 너비(384)에 맞춰 높이 비율 계산
    scale = FPGA_WIDTH / orig_w
    new_w = FPGA_WIDTH
    new_h = int(orig_h * scale)
    total_pixels = new_w * new_h

    # 3. 비디오 저장을 위한 Writer 설정 (MP4V 코덱)
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(DESKTOP_PATH, fourcc, fps, (new_w, new_h), isColor=False)

    # 4. 시리얼 포트 연결
    try:
        ser = serial.Serial(PORT, BAUD_RATE, timeout=1)
        ser.reset_input_buffer()
        print(f"🔌 FPGA 연결 성공! ({new_w}x{new_h} 해상도로 처리 시작)")
    except Exception as e:
        print(f"❌ 포트 에러: {e}")
        return

    frame_count = 0
    start_time = time.time()

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break # 영상 끝

            # 전처리: 리사이즈 -> 흑백 -> 1차원 배열
            resized = cv2.resize(frame, (new_w, new_h))
            gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
            send_data = gray.flatten().tobytes()

            # 수신 준비
            global received_frame_data
            received_frame_data = bytearray()
            receive_done.clear()
            
            rx_t = threading.Thread(target=receive_thread, args=(ser, total_pixels))
            rx_t.start()

            # 송신
            ser.write(send_data)

            # 이 프레임 처리가 끝날 때까지 대기 (Frame Sync)
            receive_done.wait()

            # 결과 조립 및 저장
            result_frame = np.frombuffer(received_frame_data, dtype=np.uint8).reshape((new_h, new_w))
            out.write(result_frame)

            frame_count += 1
            if frame_count % 10 == 0:
                print(f"🎬 {frame_count} 프레임 처리 중...")

            # 화면에 실시간으로 보여주기 (선택 사항)
            cv2.imshow('FPGA Video Processing', result_frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

    finally:
        end_time = time.time()
        print(f"\n✅ 처리 완료! 총 소요 시간: {end_time - start_time:.2f}초")
        print(f"📍 저장 위치: {DESKTOP_PATH}")
        cap.release()
        out.release()
        ser.close()
        cv2.destroyAllWindows()

if __name__ == '__main__':
    main()