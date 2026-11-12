# austrumi-ko

[English](README.md) | **한국어**

[AUSTRUMI](https://ftp.linux.edu.lv/austrumi/) 5.3.0 라이브 ISO를 영어 인터페이스에 한글 입력기와 한글 글꼴을 갖춘 시스템으로 다시 만들어 주는 스크립트 하나입니다.

AUSTRUMI는 라트비아에서 만든 슬랙웨어 기반의 작은 라이브 리눅스로, 전체가 램에서 실행됩니다. 기본 상태에서는 라트갈레어로 시작하고 한글 입력기도 한글 글꼴도 없습니다. 이 스크립트가 그 부분을 고쳐서 부팅 가능한 새 ISO를 만듭니다.

> **상태: QEMU에서만 시험했습니다.** USB나 DVD에 기록해 실제 PC에서 부팅해 보지는 않았습니다. 사용하기 전에 [시험한 것](#시험한-것)과 [알려진 문제](#알려진-문제)를 읽어 주세요.

## 새 ISO에 들어가는 것

| 항목 | 결과 |
|---|---|
| 언어 | 모든 부팅 항목에서 영어 인터페이스(`en_US.utf8`) |
| 한글 입력 | fcitx5 + fcitx5-hangul. **오른쪽 Alt**(한/영 키) 또는 Ctrl+Space로 전환 |
| 키보드 | US 배열. 오른쪽 Alt = 한/영 키, 오른쪽 Ctrl = 한자 키 |
| 글꼴 | Noto Sans KR, Noto Serif KR(Regular + Bold), 나눔스퀘어 |
| 글꼴 이름 | 문서가 "Noto Sans CJK KR" / "Noto Serif CJK KR"을 지정해도 KR 글꼴로 표시 |
| 데스크톱 | 로그인 화면 없이 `austrumi` 사용자로 FVWM2가 바로 시작 |
| 시간 | 시간대 Asia/Seoul. 하드웨어 시계가 UTC인 PC를 위한 부팅 항목 추가 |
| 창 | 새 창이 FVWM 왼쪽 패널 옆에 놓이도록 조정. LibreOffice에 저장돼 있던 1920×1080용 창 크기 삭제 |
| 시작 메뉴 | 왼쪽 위 아이콘 옆에 열리는 분류 줄이, 포인터가 아이콘이나 줄 위에 있는 동안 닫히지 않음 |
| 크기 | 약 603 MB(원본 574 MB). 부팅할 때 전부 램에 올라갑니다 |

## 준비물

- 데비안/우분투 계열 리눅스(Xubuntu 26에서 작성하고 사용했습니다)
- `sudo apt install xorriso squashfs-tools curl xz-utils`
- 원본 ISO `austrumi64-5.3.0.iso` (<https://ftp.linux.edu.lv/austrumi/>)
- 빌드 중 인터넷 연결(패키지와 글꼴 약 70 MB)
- 시스템을 풀어 놓을 **리눅스 파일시스템**(ext4 등)의 여유 공간 약 2.5 GB. 기본 위치는 `/var/tmp`
- ISO가 있는 폴더의 여유 공간 약 1.4 GB(파일시스템 종류 무관, NTFS 드라이브도 가능)
- 나눔스퀘어는 내 컴퓨터에 설치된 것을 복사합니다(`sudo apt install fonts-nanum`). 설치돼 있지 않으면 스크립트가 그 패키지를 직접 받습니다

## 빌드

```bash
chmod +x austrumi-ko.sh
sudo ./austrumi-ko.sh /경로/austrumi64-5.3.0.iso
```

원본 옆에 `austrumi64-5.3.0-ko.iso`가 만들어집니다. 몇 분 걸립니다. 원본 ISO는 건드리지 않으며, 작업 파일은 끝나면 지웁니다.

### 옵션

`sudo` 바로 뒤에 적습니다. 예: `sudo NOBOLD=1 AUTOLOGIN=Wayfire ./austrumi-ko.sh 파일.iso`

| 옵션 | 기본값 | 뜻 |
|---|---|---|
| `AUTOLOGIN` | `FVWM2` | 로그인 없이 시작할 데스크톱: `FVWM2`, `Wayfire`, `LabWC`, `Sway`. `none`이면 로그인 화면 유지 |
| `TZNAME` | `Asia/Seoul` | 시간대. 호스트의 `/usr/share/zoneinfo`에서 복사 |
| `RTC` | `localtime` | `utc`로 하면 모든 부팅 항목에서 PC 시계를 UTC로 취급(리눅스만 쓰는 내 PC용. 이렇게 만든 ISO는 배포하지 마세요) |
| `NOBOLD` | `0` | `1`이면 Noto 글꼴의 Bold를 빼서 램 약 13 MB 절약 |
| `NANUM_DIR` | – | 스크립트가 `NanumSquare*.ttf`를 찾지 못할 때 그 파일이 있는 폴더 |
| `WORKDIR` | `/var/tmp` | 시스템을 풀어 놓는 곳. 리눅스 파일시스템이어야 함 |
| `PAUSE` | `0` | `1`이면 다시 묶기 전에 멈춰서 파일을 직접 고칠 수 있음 |
| `KEEP` | `0` | `1`이면 작업 파일을 남김 |

## QEMU로 시험하기

```bash
qemu-system-x86_64 -enable-kvm -cpu host -m 4G -rtc base=localtime -cdrom austrumi64-5.3.0-ko.iso
```

옵션마다 이유가 있습니다.

- `-cpu host`: 없으면 *"Fatal glibc error: CPU does not support x86-64-v2"* 오류로 멈춥니다.
- `-m 4G`: QEMU 기본 메모리는 너무 작습니다. 약 600 MB를 램으로 복사하는 단계에서 멈춥니다.
- `-rtc base=localtime`: 가상 시계를 윈도 PC처럼 동작시켜 1번 부팅 항목에서 시간이 맞게 나옵니다.

## 사용법

- 로그인을 물으면 사용자 `austrumi`, 암호 `austrumi`.
- **오른쪽 Alt**로 영어와 한글을 전환합니다. Ctrl+Space도 같습니다.
- 부팅 메뉴 1번은 FVWM2를 시작합니다. **5번**은 같은 것이되 하드웨어 시계가 UTC인 PC(리눅스만 쓰는 PC)용입니다. 1번에서 시계가 9시간 늦으면 5번을 쓰세요.
- FVWM에서: 왼쪽 위 아이콘에 포인터를 올리면 시작 메뉴 줄이 열리고, 그대로 줄 위로 옮기면 됩니다. Alt + 왼쪽 버튼 끌기는 창 이동, Alt + 오른쪽 버튼 끌기는 크기 조절, 제목 표시줄 두 번 클릭은 패널 옆으로 최대화.

## 동작 원리

AUSTRUMI 5.3.0 ISO는 시스템을 두 파일에 나눠 담고 있고, 스크립트는 둘 다 고칩니다.

- `/austrumi/austrumi.fs`: `bin lib lib64 sbin usr`만 담은 squashfs. 프로그램, 글꼴, 키보드 데이터가 여기 들어갑니다.
- `/austrumi/austrumi.tgz`: 나머지 전부(`etc`, `var` 등). 이 안의 `etc/skel`이 부팅할 때 `root`와 `austrumi`의 홈 폴더가 되므로 설정은 모두 여기에 넣습니다.

순서: ISO를 마운트하고, 두 파일을 풀고, AUSTRUMI의 init이 하는 방식대로 합친 다음, slackware-current 패키지(`libhangul`, `xcb-imdkit`, `fcitx5`, `fcitx5-hangul`, `fcitx5-gtk`)를 설치하고, 글꼴을 넣고, 설정을 쓰고, 두 파일을 다시 묶고, `xorriso`로 원본의 부트 레코드를 그대로 살려 ISO를 만듭니다.

## 시험한 것

QEMU에서 부팅해 확인한 것(BIOS 부팅, 1280×800):

- 부팅, 영어 메뉴, 자동 로그인
- 텍스트 편집기와 LibreOffice Writer에서 fcitx5 한글 입력
- 한글 글꼴 표시, Writer에서 CJK 글꼴 이름 대체
- FVWM2 세션, 패널의 미국 국기, 서울 시간
- LibreOffice Writer가 패널 옆에, 화면에 맞는 크기로 열림
- 오른쪽 Alt를 한/영 키로 쓰는 US 키보드 배열
- 시작 메뉴 줄이 포인터가 아이콘이나 줄 위에 있는 동안 열려 있고, 벗어나면 닫힘

전혀 시험하지 않은 것:

- USB나 DVD로 실제 PC에서 부팅
- UEFI 부팅
- LabWC, i3, E16 세션과 기본 테마가 아닌 FVWM 테마

## 알려진 문제

| 증상 | 원인과 해결 |
|---|---|
| *CPU does not support x86-64-v2* | QEMU에 `-cpu host`가 없음. 실제 PC라면 CPU가 AUSTRUMI 5.x에 비해 너무 오래됨 |
| 램으로 복사하는 중 멈춤 | 메모리 부족. QEMU에 `-m 4G`를 주거나 부팅 줄에 `nocache` 추가 |
| 시계가 9시간 늦음 | PC 시계가 UTC임. 부팅 메뉴 5번을 쓰거나, 본인용으로 `RTC=utc`로 빌드 |
| 내려받기에서 빌드가 멈춤 | 미러 실패. 슬랙웨어 미러 다섯 곳을 차례로 시도하니 다시 실행 |
| *work folder … cannot hold Linux owners* | `WORKDIR`이 NTFS/exFAT/FAT에 있음. 리눅스 디스크의 폴더로 지정 |
| UEFI에서 ISO가 부팅되지 않음 | 원본과 똑같이 BIOS 부트 레코드만 있음. UEFI용 파일(`/EFI/BOOT`, rEFInd)은 AUSTRUMI 방식의 USB 설치를 위해 들어 있으나 여기서는 시험하지 않음 |
| 빌드 중 `name mapping: … -> ?` | 문제 없음. 이미지에 `fc-match`가 없어서 검사를 못 할 뿐 |
| Wayfire에서 창을 끌면 사라짐(QEMU) | 그래픽 가속 없이 흔들리는 창 효과가 켜져 있어서로 보임. 이 스크립트 탓이 아님 |
| Sway에서 창을 끌 수 없음 | Sway는 타일형 창 관리자라 원래 그렇게 동작함 |
| 영어 상태에서 트레이에 "kr" 표시 | 이미지의 키보드 규칙에 `korean:ralt_hangul`이 없어 `kr(kr104)` 배열로 대체됨(빌드할 때 NOTE 출력) |
| 오른쪽 Alt 전환이 안 됨 | Ctrl+Space를 쓰고 이슈를 남겨 주세요 |
| 시작 메뉴 줄이 사라지거나 닫히지 않음 | 줄 수정이 그 환경에서 제대로 동작하지 않는 것. 수정을 넣지 못했으면 빌드가 WARNING을 출력함. 그렇지 않으면 이슈를 남겨 주세요 |
| 몇 달 뒤 빌드 실패 | 패키지를 계속 바뀌는 **slackware64-current**에서 받음. 새 fcitx5가 이 AUSTRUMI에 없는 라이브러리를 요구할 수 있으며, 그러면 빌드가 WARNING으로 목록을 보여 줌 |

알아 둘 한계:

- 스크립트는 **AUSTRUMI 5.3.0**의 파일 구조에 맞춰 썼습니다. 다른 버전은 다를 수 있고, 기대한 파일이 없으면 스크립트가 멈춥니다.
- 창 맞춤과 시작 메뉴 수정은 FVWM 기본 테마(`fvwm2rc_5`)에만 들어갑니다.
- Noto 글꼴은 한국어 전용판입니다. 한글과 한국에서 쓰는 한자는 포함하지만 중국어·일본어 전용 글자는 없습니다.

## 라이선스와 출처

- 스크립트: MIT. [LICENSE](LICENSE) 참고.
- [AUSTRUMI](https://ftp.linux.edu.lv/austrumi/)와 슬랙웨어 패키지는 각자의 라이선스를 따릅니다. 다시 만든 ISO에는 이것들이 모두 들어 있으니 ISO를 재배포하기 전에 해당 라이선스를 확인하세요.
- [Noto CJK](https://github.com/notofonts/noto-cjk) 글꼴: SIL Open Font License 1.1.
- 나눔스퀘어(네이버): SIL Open Font License 1.1.
- [fcitx5](https://github.com/fcitx/fcitx5), fcitx5-hangul, libhangul: 각자의 자유 라이선스.

이 스크립트는 Claude(Anthropic의 AI 어시스턴트)와의 대화에서 실제 ISO를 들여다보고 빌드할 때마다 QEMU로 시험하면서 단계적으로 만들었습니다.
