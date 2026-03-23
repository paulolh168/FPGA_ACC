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
BAUD_RATE = 921600  # Verilog 코드를 921600으로 수정했다면 여기도 921600으로 변경해야 함
image_path = 'test.jpg' 

# 수신 데이터를 모을 바이트 배열과 완료 신호
received_pixels = bytearray()
receive_complete = threading.Event()

def receive_thread(ser, total_bytes):
    """FPGA에서 오는 데이터를 묵묵히 주워 담는 수신 전용 스레드"""
    global received_pixels
    while len(received_pixels) < total_bytes:
        waiting = ser.in_waiting
        if waiting > 0:
            chunk = ser.read(waiting)
            received_pixels.extend(chunk)
    receive_complete.set()

def main():
    # ==========================================
    # 2. 이미지 읽기 및 전처리
    # ==========================================
    if not os.path.exists(image_path):
        print(f"❌ 경로에서 파일을 찾을 수 없다: {image_path}")
        return

    image = cv2.imread(image_path, cv2.IMREAD_COLOR)

    if image is None:
        print("❌ 파일을 읽을 수 없다.")
        return

    scale_factor = 0.1
    new_width = int(image.shape[1] * scale_factor)
    new_height = int(image.shape[0] * scale_factor)

    resized_image = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_LINEAR)
    gray_image = cv2.cvtColor(resized_image, cv2.COLOR_BGR2GRAY)

    img_flattened = gray_image.flatten()
    total_pixels = len(img_flattened)
    print(f"👉 변환 완료: {new_width}x{new_height} (총 {total_pixels} 픽셀)")

    # ==========================================
    # 3. FPGA 풀-듀플렉스(스레드) 고속 통신
    # ==========================================
    try:
        ser = serial.Serial(PORT, BAUD_RATE, timeout=1)
        ser.reset_input_buffer()
        print("\n🔌 FPGA 보드와 통신 시작! (비동기 풀-듀플렉스 모드)\n")

        # 수신 스레드 시작
        rx_thread = threading.Thread(target=receive_thread, args=(ser, total_pixels))
        rx_thread.start()

        start_time = time.time()

        # 송신 (메인 스레드)
        for row in range(new_height):
            start_idx = row * new_width
            end_idx = start_idx + new_width
            chunk_to_send = img_flattened[start_idx:end_idx]
            
            ser.write(bytes(chunk_to_send))
            
            # 진행률 표시 (10% 단위)
            if (row + 1) % max(1, (new_height // 10)) == 0 or (row + 1) == new_height:
                progress = ((row + 1) / new_height) * 100
                print(f"⏳ 송신 진행률: {progress:.0f}% 완료...")

        print("TX: 송신 완료. RX 수신 대기 중...")
        
        # 수신 완료 대기
        receive_complete.wait()
        end_time = time.time()
        print(f"\n🎉 통신 완벽하게 종료! (소요 시간: {end_time - start_time:.2f}초)")

        # ==========================================
        # 4. 결과 이미지 조립 및 화면 출력
        # ==========================================
        result_array = np.array(received_pixels, dtype=np.uint8).reshape((new_height, new_width))

        cv2.imshow("Original (Grayscale)", gray_image)
        cv2.imshow("FPGA Result (Edge)", result_array)
        
        print("\n👀 이미지 창을 확인해라! (창 닫기: 아무 키나 누르기)")
        cv2.waitKey(0)
        cv2.destroyAllWindows()

    except Exception as e:
        print(f"❌ 통신 에러 발생: {e}")

    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("🔌 포트가 안전하게 닫혔다.")

if __name__ == '__main__':
    main()