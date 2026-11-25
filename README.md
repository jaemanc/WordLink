# WordLink

카드를 골라 새 단어를 만들고 목표 단어에 도달하는 Flutter 모바일 퍼즐입니다. 한 번에 Easy는 4장, Normal은 8장, Hard는 16장을 조합합니다. 모드마다 한 스테이지가 있으며 최단 클리어에는 Easy 10번, Normal 15번, Hard 20번의 성공한 조합이 필요합니다.

조합 규칙과 임베딩을 앱에 내장해 오프라인에서 플레이할 수 있습니다. 카드 선택에는 진동과 스케일 애니메이션이, 조합에는 충돌과 파티클 효과가 적용됩니다.

## 실행

최신 안정 채널 Flutter와 iOS 시뮬레이터 또는 Android 에뮬레이터를 준비합니다.

```sh
flutter pub get
flutter devices
flutter run
flutter test
```

카드를 탭해 작업대에 넣고, 카드나 작업대의 삭제 아이콘을 탭해 선택을 해제합니다. 화면 하단에는 선택한 카드 수와 조합 버튼이 고정됩니다. 첫 시도에는 **모두 선택**, 조합 후에는 **이전 재료 선택**을 눌러 필요한 카드만 바꿀 수 있습니다.

Easy의 첫 조합은 **밀 + 물 + 불 + 소금 → 반죽**입니다. 카드의 속성은 보유 단어에서 확인하거나 필터링할 수 있습니다. Easy는 다음에 바꿀 카드가 바로 표시되고 Normal과 Hard는 **다음 조합 힌트**를 펼쳐 확인할 수 있습니다. 힌트를 따라갈 때 **이전 재료 선택**을 누르면 해당 힌트의 기준 재료를 불러옵니다.

## 프로젝트 구조

```text
WordLink/
├── android/                         Android 실행 프로젝트
├── ios/                             iOS 실행 프로젝트
├── assets/
│   ├── stages.json                  스테이지, 정답, 조합 규칙
│   └── embeddings.json              단어별 샘플 벡터
├── lib/
│   ├── main.dart                    앱 테마와 ProviderScope
│   ├── models.dart                  Stage, WordItem, CombinationRule, CraftOutcome
│   ├── local_knowledge_service.dart  에셋 로딩, 규칙·코사인 계산 및 캐시
│   ├── game_controller.dart         Riverpod 상태와 시도·인벤토리 갱신
│   └── game_screen.dart             카드·작업대·기록 및 조합 이펙트
├── test/
│   └── local_knowledge_service_test.dart
└── pubspec.yaml
```

## 로컬 데이터

- `Stage`는 ID, 난이도, 목표, 시작 카드, 기준 횟수, 규칙, 허용 정답을 담습니다. `WordItem`은 단어, 이모지, 속성(`material`, `energy`, `tool`, `environment`, `component`, `phenomenon`)을 담습니다.
- `CombinationRule`은 결과 단어, 속성, 설명, 선택적 다음 조합 힌트를 담습니다. 키는 필요한 4개, 8개 또는 16개의 서로 다른 단어를 Dart `String.compareTo` 순서로 정렬한 뒤 `|`로 연결합니다. Easy의 첫 조합 키는 `물|밀|불|소금`입니다.
- `CraftOutcome`은 입력 카드 목록, 결과 카드, 설명, 결과 근접도, 정답 도달 여부를 담습니다.
- `embeddings.json`은 단어를 동일한 차원의 숫자 배열에 대응시킵니다. 동봉된 벡터는 피드백 강도를 조정한 9차원 샘플입니다. 오프라인에서 생성한 벡터를 같은 포맷으로 교체할 수 있습니다.
- 서비스는 벡터를 로드할 때 정규화하고 `round(clamp(cosine, 0, 1) * 100)`으로 근접도를 표시합니다. 클리어는 목표 단어 또는 허용 정답과 일치할 때 판정합니다. Hard의 `극광`도 정답입니다.
- 등록되지 않은 조합은 조합 불가로 처리합니다. 모든 시도는 기록과 횟수에 반영되며 재료 카드는 계속 사용할 수 있습니다. 결과 카드는 단어당 한 장만 추가됩니다.
- 기준 이하면 3성, 기준보다 1~2회 많으면 2성, 그 이상이면 1성입니다. 플레이 진행은 실행 세션에 보관됩니다.
