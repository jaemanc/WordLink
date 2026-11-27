"""Rebuild the Korean display text using the checked-in offline glossary."""
import json
from pathlib import Path

from build_campaign import ALTERNATIVES, BATCHES, EDITIONS, STYLES, THEMES

ROOT = Path(__file__).resolve().parents[1]
FIXED = {
    "Classic": "고전형", "Experimental": "실험형", "Compact": "소형",
    "Custom": "맞춤형", "Standard": "표준형", "Deluxe": "고급형",
    "Limited Edition": "한정판", "Special": "특별형", "Prototype": "시제품",
    "Signature": "대표형", "Compact Series": "소형 시리즈",
    "Field Series": "현장용 시리즈", "Workshop Series": "작업장 시리즈",
    "Select Series": "엄선 시리즈", "Heritage Series": "전통 시리즈",
    "Utility Series": "실용 시리즈", "Premium Series": "프리미엄 시리즈",
    "Limited Series": "한정 시리즈", "Showcase Series": "전시 시리즈",
    "Base": "기본", "Sorted": "분류한", "Measured": "계량한", "Bench": "작업대",
    "Reserve": "비축", "Prepared": "준비한", "Spare": "예비", "Marked": "표시한",
    "Fitted": "맞춤", "Selected": "선별한", "Packed": "포장된", "Sample": "견본",
    "Tested": "시험한", "Workshop": "작업용", "Checked": "점검한", "Fresh": "새로 준비한",
    "Refined": "정제한", "Support": "보조", "Finished": "마감된", "Final": "최종",
    "Unsorted": "미분류", "Bread": "빵", "Candle": "양초", "Kite": "연",
    "Plant Pot": "화분", "Jam": "잼", "Notebook": "공책", "Drum": "북",
    "Soap": "비누", "Birdhouse": "새집", "Watercolor": "수채화", "Compass": "나침반",
    "Umbrella": "우산", "Clock": "시계", "Fabric Roll": "두루마리 천",
    "Bicycle": "자전거", "Lantern": "등불", "Guitar": "기타", "Sled": "썰매",
    "Water Filter": "정수 필터", "Radio": "라디오", "Telescope": "망원경",
    "Suspension Bridge": "현수교", "Wind Turbine": "풍력 터빈", "Satellite": "인공위성",
    "Greenhouse": "온실", "Microscope": "현미경", "Drone": "드론", "Refrigerator": "냉장고",
    "Metro Line": "도시철도 노선", "Battery Pack": "배터리 팩", "Tea": "차",
    "Mosaic": "모자이크", "Terrarium": "테라리움", "Pancake": "팬케이크",
    "Keychain": "열쇠고리", "Stained Glass Panel": "스테인드글라스 판",
    "Ink Pen": "잉크 펜", "Mechanical Scale": "기계식 저울", "Solar Cooker": "태양열 조리기",
    "Music Box": "오르골", "Hydroelectric Generator": "수력 발전기", "Weather Station": "기상 관측소",
    "Desalination Plant": "담수화 시설", "Ocean Buoy": "해양 부표", "Robotic Arm": "로봇 팔",
    "Rye": "호밀", "Cactus": "선인장", "Water": "물", "Flour": "밀가루",
    "Spoon": "숟가락", "Bowl": "그릇", "Salt": "소금", "Sugar": "설탕", "Dough": "반죽",
}

# Common words and ambiguous workshop terms use the intended puzzle meaning.
FIXED.update({
    "Field": "현장용", "Travel": "여행용", "Garden": "정원", "Trail": "산길",
    "Harbor": "항구", "Kitchen": "주방", "Survey": "측량용", "School": "학교",
    "Mountain": "산악", "Marine": "해양용", "Weather": "기상", "Lab": "실험실",
    "Forest": "숲", "Valley": "계곡", "Oat": "귀리", "Ocean": "바다",
    "Pocket": "휴대형", "Fern": "고사리", "Moss": "이끼", "Linen": "리넨",
    "Rose": "장미", "Lavender": "라벤더", "Star": "별", "Herb": "허브",
    "Sketch": "스케치", "Floral": "꽃무늬", "Patio": "테라스", "Folk": "포크",
    "Studio": "스튜디오", "Rescue": "구조용", "Market": "시장", "River": "강",
    "Offshore": "해상", "Farm": "농장", "Island": "섬", "Research": "연구용",
    "Inspection": "점검용", "Honey": "꿀", "Orange": "오렌지", "Pine": "소나무",
    "Practice": "연습용", "Mapping": "지도 제작용", "Wooden": "나무",
    "Pantry": "식료품 저장실", "Portable": "휴대용", "Frame": "틀", "Glass": "유리",
    "Stage": "받침대", "Marker": "표시 도구", "Hand": "손잡이용", "Wool": "양모",
    "Wheat": "밀", "Spelt": "스펠트밀", "Seeded": "씨앗을 넣은", "Vanilla": "바닐라",
    "Fish": "물고기", "Ivy": "담쟁이덩굴", "Strawberry": "딸기", "Raspberry": "라즈베리",
    "Plum": "자두", "Recipe": "요리법", "Study": "학습용", "Snare": "스네어",
    "Marching": "행진용", "Olive": "올리브", "Tea Tree": "티트리", "Oak": "참나무",
    "Maple": "단풍나무", "Spruce": "가문비나무", "Sunset": "노을", "Mint": "박하",
    "Jasmine": "재스민", "Tape": "테이프", "Spring": "스프링", "Ruler": "자",
    "Sourdough": "천연 발효", "Cedar": "삼나무", "Barley": "보리", "Country": "시골풍",
    "Riveted Frame": "리벳으로 고정한 틀", "Salt Spray Trial": "염수 분무 시험",
    "Capillary Feed": "모세관 급지부", "Clay Lump": "점토 덩어리", "Cut Canvas": "자른 천",
    "Key": "열쇠", "Cut": "자른", "Clamp": "고정 집게", "Heat": "열", "Wind": "바람",
    "Wick": "심지", "Penstock": "수압관", "Blade": "날", "Shaft": "회전축",
    "Bearing": "베어링", "Dial": "눈금판", "Coil": "코일", "Gore": "천 조각",
    "Scored Loaf": "칼집을 낸 반죽", "Steamed Crust": "증기를 입힌 빵 껍질",
})


def plan():
    catalog = json.loads((ROOT / "assets/stages.json").read_text(encoding="utf-8"))
    target_themes = {row[1]: row[2] for row in catalog["stages"]}
    authored = {term for theme in THEMES for term in theme[3].split(",")}
    authored.update(term for line in ALTERNATIVES for term in line.split(","))
    prefixes = sorted({*BATCHES, "Unsorted", "Reserve"}, key=len, reverse=True)
    styles = sorted(STYLES, key=len, reverse=True)
    editions = sorted(EDITIONS[1:], key=len, reverse=True)
    result = {}
    for i, row in enumerate(catalog["words"]):
        word = row[0]
        if i in target_themes:
            tema = THEMES[target_themes[i]]
            core = tema[3].split(",")[-1]
            style = next(value for value in styles if word.startswith(value + " "))
            edition = next((value for value in editions if word.endswith(" " + value)), "")
            body = word[len(style)+1 : -(len(edition)+1) if edition else None]
            modifier = body.removesuffix(" " + core)
            if modifier == body:
                raise ValueError(f"Unknown target structure: {word}")
            result[word] = ((modifier, core), (style, edition) if edition else (style,))
        elif len(row) > 3 or word in authored:
            result[word] = ((row[3] if len(row) > 3 else word,), ())
        else:
            parts = []
            body = word
            for _ in range(2):
                prefix = next((prefix for prefix in prefixes if body.startswith(prefix + " ")), None)
                if prefix is None:
                    break
                parts.append(prefix)
                body = body[len(prefix)+1:]
            result[word] = ((*parts, body), ())
    return result


def write_labels(glossary):
    glossary = glossary | FIXED
    labels = {}
    for word, (terms, annotations) in plan().items():
        label = " ".join(glossary[term] for term in terms)
        if annotations:
            label += " (" + "·".join(glossary[term] for term in annotations) + ")"
        labels[word] = label
    path = ROOT / "assets/word_labels_ko.json"
    path.write_text(
        "{\n" + ",\n".join(json.dumps(key) + ":" + json.dumps(value, ensure_ascii=False)
                              for key, value in labels.items()) + "\n}\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    glossary_path = ROOT / "tool/word_labels_ko_terms.json"
    write_labels(json.loads(glossary_path.read_text(encoding="utf-8")))
