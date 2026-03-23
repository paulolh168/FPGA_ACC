import serial
import cv2
import numpy as np
import time
import os

# ==========================================
# 1. 환경 설정
# ==========================================
PORT = 'COM4'       # ⚠️ 본인 PC 장치 관리자에 잡힌 포트로 반드시 확인!
BAUD_RATE = 921600
image_path = 'C:/Users/USER/Desktop/test.jpg' # 테스트할 원본 이미지 경로

# ==========================================
# 2. 이미지 읽기 및 전처리
# ==========================================
if not os.path.exists(image_path):
    print(f"❌ 경로에서 파일을 찾을 수 없습니다: {image_path}")
    exit()

image = cv2.imread(image_path, cv2.IMREAD_COLOR)

if image is None:
    print("❌ 파일을 읽을 수 없습니다.")
    exit()

print(f"✅ 원본 이미지 읽기 성공! (크기: {image.shape[1]}x{image.shape[0]})")

# 20% 크기로 축소 (예: 3840x2880 -> 768x576)
scale_factor = 0.1  
new_width = int(image.shape[1] * scale_factor)
new_height = int(image.shape[0] * scale_factor)

# 이미지 리사이즈 및 흑백 변환 (FPGA는 1픽셀=1바이트로 처리하니까!)
resized_image = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_LINEAR)
gray_image = cv2.cvtColor(resized_image, cv2.COLOR_BGR2GRAY)

# 2차원 이미지를 1차원 배열로 쫙 펼침
img_flattened = gray_image.flatten()
total_pixels = len(img_flattened)
print(f"👉 변환 완료: {new_width}x{new_height} (총 {total_pixels} 픽셀 / 약 {total_pixels/1024:.0f} KB)")

# ==========================================
# 3. FPGA 1줄(Row) 묶음(Chunk) 고속 통신
# ==========================================
received_pixels = bytearray() # 받은 데이터를 차곡차곡 쌓을 바구니

try:
    # timeout=None: 요청한 바이트 수가 다 들어올 때까지 무한정 기다림 (안전성 100%)
    ser = serial.Serial(PORT, BAUD_RATE, timeout=None)
    ser.reset_input_buffer()
    print("\n🔌 FPGA 보드와 통신 시작! (고속 청크 전송 모드)\n")

    start_time = time.time()

    # 세로줄(new_height, 예: 576)만큼 반복
    for row in range(new_height):
        # 배열에서 딱 가로 1줄(new_width, 예: 768개)만큼 잘라내기
        start_idx = row * new_width
        end_idx = start_idx + new_width
        chunk_to_send = img_flattened[start_idx:end_idx]
        
        # 1. [송신] 한 줄(768바이트)을 PC 송신 버퍼에 와르르 쏟아부음!
        ser.write(bytes(chunk_to_send))
        
        # 2. [수신] 보낸 만큼(768바이트) 돌아올 때까지 수신 버퍼 앞에서 대기 후 긁어옴!
        # (이 짧은 순간 케이블에서는 Full-Duplex 동시 송수신이 일어남)
        chunk_received = ser.read(new_width)
        
        # 3. 받은 한 줄을 전체 바구니에 담기
        received_pixels.extend(chunk_received)

        # 진행률 표시 (10% 단위로)
        if (row + 1) % (new_height // 100) == 0 or (row + 1) == new_height:
            progress = ((row + 1) / new_height) * 100
            print(f"⏳ 전송 진행률: {progress:.0f}% 완료... (현재 {row+1}/{new_height} 줄)")

    end_time = time.time()
    print(f"\n🎉 통신 완벽하게 종료! (소요 시간: {end_time - start_time:.2f}초)")

    # ==========================================
    # 4. 결과 이미지 조립 및 화면 출력
    # ==========================================
    # 1차원 바구니 데이터를 다시 원래 형태(576 x 768)의 2차원 배열로 조립
    result_array = np.array(received_pixels, dtype=np.uint8).reshape((new_height, new_width))

    # 화면에 나란히 띄워서 비교하기 (보기 편하게 살짝 줄여서 띄움, 해상도 너무 크면 모니터 넘침 방지)
    cv2.imshow("Original (Grayscale)", gray_image)
    cv2.imshow("FPGA Result (+1 Processed)", result_array)
    
    print("\n👀 이미지 창을 확인해 봐! (창을 닫으려면 이미지 창 클릭 후 아무 키나 누르기)")
    cv2.waitKey(0)
    cv2.destroyAllWindows()

except Exception as e:
    print(f"❌ 통신 에러 발생: {e}")

finally:
    if 'ser' in locals() and ser.is_open:
        ser.close()
        print("🔌 포트가 안전하게 닫혔습니다.")