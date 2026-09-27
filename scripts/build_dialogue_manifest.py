"""Single source of truth for the campaign's voiced lines.

Writes godot_project/data/zh_dialogue.json (id -> speaker/text, read by chapter_audio.gd) and
godot_project/assets/audio/zh/manifest.json (per-clip voice, duration and SHA-256 of the mp3).
Every clip is AI-synthesized speech in voices chosen by the user; none is a recording of a
named real actor. A line whose clip has not been synthesized yet is listed with "file": null and
plays as a timed subtitle in game (chapter_audio.speak falls back to text length).

Run after adding or regenerating clips:  python3 scripts/build_dialogue_manifest.py
"""
import hashlib, json, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
AUDIO = ROOT / 'godot_project/assets/audio/zh'
DIALOGUE = ROOT / 'godot_project/data/zh_dialogue.json'
VOICES = {'指挥中心': 'voice-00', '陈默': 'voice-01', '沈国栋': 'voice-02'}
# (id, speaker, chapter, text) in play order. Chapter one texts are unchanged from the first release.
LINES = [
    ('intro', '指挥中心', 1, '这里是指挥中心。林舟，北码头的停电不是事故。证人陈默被困在九号仓库，他手里的运输记录，是我们找到失踪人员的唯一线索。先恢复通道，再带他平安回来。'),
    ('checkpoint', '指挥中心', 1, '门禁记录收到了。封锁命令在停电前六分钟就已下达，这不是临时处置。仓库外的中继箱正在向他们发送警报，切断上行，我来释放装卸门。'),
    ('relay', '指挥中心', 1, '报警上行已切断，装卸门解锁。仓库使用独立应急电源，照明不会中断。陈默最后的位置在仓库深处，确认身份后立即带离。'),
    ('rescue', '陈默', 1, '我叫陈默，是这里的调度员。清单上写着空箱，可我听见里面有人敲门。我把记录藏了起来，他们才没有立刻把我带走。警官，请相信我，那批货今晚还会转运。'),
    ('evidence', '陈默', 1, '记录就在这张存储卡里。名单和货柜编号能一一对应，还有今晚的转运地点。我不认识里面的人，但我不能装作什么都没听见。'),
    ('evac', '指挥中心', 1, '撤离车辆已就位。林舟，别把陈默留在身后，两个人都进入接应区后再确认撤离。记录的备份正在上传，接应组会保护他的安全。'),
    ('debrief', '指挥中心', 1, '证人已接应，存储卡校验通过。运输记录指向今晚的一次转运，我们还有机会找到那些人。你带回来的不只是证据，也是一个愿意开口的人。'),
    ('reinforcements', '指挥中心', 1, '注意，街区南侧出现两名增援。借助车辆和路障逐段推进，先确认下一个掩体，再让陈默跟上。不要在开阔地停留。'),
    ('yard_intro', '指挥中心', 2, '林舟，堆场夜班在两小时前被全部遣散，理由是例行安保演练。签发人的名字我们还在查。CN 20437 在冷藏箱区，先拿下闸口，别让他们把箱子装上车。'),
    ('yard_gate', '陈默', 2, '警官，是我，陈默。指挥中心让我在线上帮你。堆场的巷道是按字母编的，冷藏箱区在 D 巷尽头。他们说的“例行演练”是假的——夜班从来不会全撤。'),
    ('yard_office', '指挥中心', 2, '调度记录到了。今天下午有人用港务局保安主管的权限改了 CN 20437 的堆位，签名是沈国栋——五点零六分下达封锁命令的也是他。林舟，箱子里的人还活着，去 D 巷。'),
    ('yard_container', '陈默', 2, '箱门开了？里面有六个人……对，就是我在清单上看到的那六个“空箱”。警官，谢谢你没有把我的话当成疯话。让他们靠着箱壁坐下，接应组三分钟内到 D 巷。'),
    ('yard_intercept', '沈国栋', 2, '所有人听着，堆场丢了一只箱子，无所谓。潮汐号零点整随潮离港，剩下的货已经在船上。守住三号泊位到零点，然后各自消失。'),
    ('yard_debrief', '指挥中心', 2, '出口闸已封锁，六个人都活着，接应组接手。截获的对讲确认了：沈国栋在潮汐号上，零点随潮离港。港务局的离港许可我们无法远程撤销，必须有人上舷梯。林舟，下一站三号泊位。'),
    ('pier_intro', '指挥中心', 3, '林舟，三号泊位的陆侧已经封死，他们只剩海上这一条路。潮汐号四十分钟后满潮，许可一撤，引水员就不会登船。沿码头推进到舷梯，我们在你身后。'),
    ('pier_gate', '陈默', 3, '警官，三号泊位我熟。岸吊底下有一排系缆桩，那是最好的掩体；舷梯在船尾方向，旁边就是港务终端。潮汐号的船员大多是被雇来的，真正的枪都在沈国栋身边。'),
    ('pier_hold', '指挥中心', 3, '岸吊区安全，接应组跟进到你身后。热成像看到船尾有两个人在解缆，他们想提前走。林舟，别等零点了，现在就上舷梯。'),
    ('pier_terminal', '沈国栋', 3, '林警官，你走到这里，说明你比我想的固执。可你撤不掉的东西还有很多——名单、船期、下一个港口。你救了七个人，剩下的呢？回去吧，天亮以后这里还是港口，还是我的港口。'),
    ('pier_arrest', '指挥中心', 3, '许可已撤销，引水员拒绝登船，潮汐号哪里也去不了。沈国栋已经控制，船上的十一个人全部找到。林舟，港口安静了——这次是我们让它安静的。回来吧，天快亮了。'),
]


def mp3_seconds(path: pathlib.Path) -> float:
    from mutagen.mp3 import MP3  # pip install mutagen
    return round(MP3(str(path)).info.length, 3)


def main() -> int:
    dialogue = '{\n' + ',\n'.join(
        '  ' + json.dumps(i) + ': ' + json.dumps({'speaker': s, 'text': t}, ensure_ascii=False, separators=(',', ':')).replace(',"text"', ', "text"')
        for i, s, _, t in LINES) + '\n}\n'
    DIALOGUE.write_text(dialogue, encoding='utf-8')
    clips, pending = [], []
    for i, speaker, chapter, text in LINES:
        path = AUDIO / f'{i}.mp3'
        clip = {'id': i, 'speaker': speaker, 'chapter': chapter, 'voice': VOICES[speaker], 'text': text}
        if path.exists():
            clip.update(file=str(path.relative_to(ROOT)).replace('\\', '/'), seconds=mp3_seconds(path),
                        sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        else:
            clip.update(file=None, seconds=None, sha256=None, status='pending-synthesis')
            pending.append(i)
        clips.append(clip)
    manifest = {
        'language': 'zh-CN',
        'source': 'AI-synthesized speech; three voices (command, Chen Mo, Shen Guodong) selected by the user in this session',
        'notice': 'Not recordings of named real actors. Commercial use subject to generation service terms.',
        'voices': {'voice-00': '指挥中心 周岚', 'voice-01': '陈默', 'voice-02': '沈国栋'},
        'clips': clips,
    }
    (AUDIO / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(clips)} lines, {len(clips) - len(pending)} clips on disk, pending: {pending or "none"}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
