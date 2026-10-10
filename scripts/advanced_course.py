"""Independent advanced course: explicit geometric oracles, never community layouts."""
from open_course import LESSONS as OPEN_LESSONS, designs as open_designs, late_obstacles

CHAPTERS = [
    ('Landmarks and geometric patterns', '地标与几何规律', '目印と幾何模様'),
    ('Reason about recursive state', '推理递归状态', '再帰の状態を考える'),
    ('Build patterns within patterns', '图案中的图案', '模様の中の模様'),
    ('Compose recursive systems', '组合递归系统', '再帰を組み合わせる'),
]


def lesson(title, goal, observation, strategy):
    return (title, goal, [observation, strategy])


LESSONS = OPEN_LESSONS + [
    lesson(('Recursive lantern', '递归灯宫', '再帰の灯宮'),
           ('Assemble four rotated subcurves by swapping two turn parameters at each level.', '每层交换两个转向参数，把四条旋转子曲线拼成整体。', '各段で二つの回転引数を交換し、四つの回転した曲線をつなごう。'),
           ('The pattern has four similar quarters, each made from four smaller quarters.', '图案分成四个相似区域，每个区域又由四个更小区域组成。', '模様には似た四区画があり、それぞれも小さな四区画でできています。'),
           ('Use depth and two opposite turns. The first and fourth subcalls exchange the turns; three two-cell links join them.', '传递深度和两个反向转向；第一、第四次子调用交换转向，用三段两格连接线拼合。', '深さと逆向きの二回転を渡し、一つ目と四つ目の子で回転を交換。二マスの三本の線で結びましょう。')),
    lesson(('Snowmelt seal', '融雪方印', '雪解けの印'),
           ('Grow an instruction motif recursively, then execute only the selected expansion level.', '递归增长指令图案，但只执行指定层的展开结果。', '命令の模様を再帰で育て、選んだ段階の展開だけを実行しよう。'),
           ('Each straight segment becomes five segments with right, left, left, right turns. Four trap caps forbid overrunning the folds.', '每条直线替换成五段，转向依次为右、左、左、右；四个陷阱端点禁止在弯折处多走。', '各直線は五区間になり、右、左、左、右と回転します。四つの罠の端では進み過ぎに注意。'),
           ('Carry the expanded instruction as a parameter. A second numeric guard selects the deepest layer before fourfold rotation.', '把展开后的指令作为参数传递，用第二个数值守卫选择最深一层，再做四向旋转。', '展開した命令を引数にし、二つ目の数値条件で最深段を選び、四方向に回転させましょう。')),
    lesson(('Lantern atlas', '灯窗图谱', '灯窓の地図'),
           ('Place four recursive copies at offsets, using depth and spacing as independent parameters.', '分别控制深度与间距，把四份递归图案放到偏移位置。', '深さと間隔を別々に制御し、四つの再帰模様をずらして配置しよう。'),
           ('Four large corner groups contain four smaller groups; each connector must be retraced.', '四个大角组内各有四个小组，每段连接线都要折返。', '四つの大きな角の組に、四つの小さな組があり、接続線は引き返します。'),
           ('Factor a corner trip that returns rotated by a quarter turn; repeat it four times and reduce spacing by three in each child.', '提取「走到角点再返回、净旋转四分之一圈」的过程；重复四次，子层间距减三。', '角へ行って戻り、四分の一回転する手続きを四回使い、子の間隔を三減らしましょう。')),
    lesson(('Dragon gallery', '龙曲画廊', 'ドラゴンの回廊'),
           ('Use two mutually recursive turns to generate a folding curve rather than a repeated tile.', '用两种相互递归的转向生成折叠曲线，而非重复单元。', '単位の反復ではなく、二種類の相互再帰で折り畳み曲線を作ろう。'),
           ('The two halves have related folds, but their turns are ordered differently.', '前后两半的折叠相关，但转向排列不同。', '前後の折り方は関連しますが、回転の順序が違います。'),
           ('One procedure expands A, right, B, walk, right; its partner expands left, walk, A, left, B.', '一个过程展开为 A、右、B、前进、右；另一个为左、前进、A、左、B。', '一方は A、右、B、前進、右、もう一方は左、前進、A、左、B と展開します。')),
    lesson(('Dragon compass', '龙纹罗盘', '竜紋の羅針盤'),
           ('Construct inverse recursive procedures so a folded curve returns before its next rotation.', '构造递归过程的逆过程，让折叠曲线折返后再旋转。', '再帰の逆手続きを作り、折り畳み曲線を戻ってから回転させよう。'),
           ('Four folded arms share a center. Finishing a curve does not automatically restore its starting pose.', '四条折叠分支共用中心；曲线结束并不会自动恢复起点和朝向。', '四つの折れた腕は中心を共有しますが、曲線の終わりでは元の位置と向きに戻りません。'),
           ('Reverse the order of each recursive body and exchange left with right; surround the inverse trip with half turns.', '把各递归体的顺序倒过来、交换左右转；执行逆程前后分别掉头。', '各再帰の本体を逆順にし、左右を交換。逆の道筋の前後で半回転しましょう。')),
    lesson(('Chiral canopy', '旋向树冠', '回転する樹冠'),
           ('Combine a branching return invariant with chirality passed through four recursive levels.', '结合分杈折返不变量与跨四层传递的旋向。', '枝分かれから戻る条件と、四段に渡す回転方向を組み合わせよう。'),
           ('The same branch is reflected differently in its two children, then reused in four directions.', '同一分支的两个子分支采用不同镜像方式，再向四个方向复用。', '同じ枝でも二つの子では反転が違い、さらに四方向へ使います。'),
           ('Pass depth, stem length and a turn. Reverse the turn for one child; return to the parent pose after both children.', '传入深度、主干长度、转向；一个子分支反转旋向，两支结束后恢复父状态。', '深さ、幹の長さ、回転を渡し、一方の子で回転を反転。両方の後で親の状態へ戻りましょう。')),
    lesson(('Vaulted mosaic', '穹顶镶嵌', '丸天井のモザイク'),
           ('Nest window, row, shrinking tier and rotation routines, each with its own return invariant.', '嵌套单窗、整行、收缩层和旋转过程，各自保持折返不变量。', '窓、行、縮む段、回転を入れ子にし、それぞれ元に戻る条件を保とう。'),
           ('Each sector has three tiers: three large windows, two medium windows, one small window.', '每个扇区有三层：三扇大窗、两扇中窗、一扇小窗。', '各区画は三段で、大窓三つ、中窓二つ、小窓一つです。'),
           ('Let the row recurse sideways and unwind back; let the tier recurse upward and unwind down, then rotate the whole sector.', '整行向侧面递归、返回时折返；整层向上递归、返回时下行，最后旋转整个扇区。', '行は横へ再帰して戻り、段は上へ再帰して下へ戻り、最後に区画全体を回転させましょう。')),
    lesson(('Astral cathedral', '星穹圣殿', '星空の聖堂'),
           ('Compose a window generator with a chiral branching tree and a higher-order rotation routine.', '把窗框生成器、带旋向的分杈树与高阶旋转过程组合成整体。', '窓枠、回転する分岐木、高階の回転手続きを組み合わせよう。'),
           ('Every node is both a square courtyard and a branch junction; depth, size and chirality change independently.', '每个节点既是方形庭院也是分杈点；深度、尺寸与旋向分别变化。', '各節は四角い庭でも分岐点でもあり、深さ、寸法、回転方向が別々に変わります。'),
           ('Prove the courtyard and each subtree return to the same pose. Build one sector from those contracts, then pass it to a fourfold repeater.', '先确认庭院与每个子树都恢复原状态；按这个约定组合一个扇区，再交给四次重复器。', '庭と各部分木が元の状態へ戻ることを確認し、一つの区画を組み立てて四回反復へ渡しましょう。')),
]

WALK = 'b(N):sb(N-1)\n'
FOUR = 'q(X):XXXX\n'


def walk(n):
    return 's' * max(n, 0)


def square(n, turn='r'):
    return (walk(n) + turn) * 4


def outline(path):
    """A one-cell masonry border constrains the route and exposes its repeated units."""
    safe = set(path)
    return sorted({(x+dx, y+dy) for x, y in safe
                   for dx, dy in [(0, -1), (1, 0), (0, 1), (-1, 0)]
                   if 0 <= x+dx < 25 and 0 <= y+dy < 25} - safe)


def advanced_designs(trace):
    result = open_designs(trace)

    def add(start, commands, source, geometry=None, traps=()):
        safe = {start, *trace(start, geometry or commands)}
        walls, traps = late_obstacles(safe, len(result)-12, traps)
        result.append((start, commands, source, sorted(safe - {start}), walls, traps))

    def hilbert(n, x='r', y='l'):
        if n == 0:
            return ''
        return (x+hilbert(n-1, y, x)+'ss'+y+hilbert(n-1, x, y)+'ss'
                +hilbert(n-1, x, y)+y+'ss'+hilbert(n-1, y, x)+x)

    add((5, 19), hilbert(3), WALK+
        'a(N,X,Y):Xa(N-1,Y,X)b(2)Ya(N-1,X,Y)b(2)a(N-1,X,Y)Yb(2)a(N-1,Y,X)X\na(3,r,l)')

    motif = 'ss'
    for _ in range(2):
        motif = motif+'r'+motif+'l'+motif+'l'+motif+'r'+motif
    add((3, 21), (motif+'r')*4,
        'a(N,X):a(N-1,XrXlXlXrX)c(2-N,X)\nc(N,X):XrXrXrXr\na(3,ss)',
        traps=[(3, 18), (6, 3), (21, 6), (18, 21)])

    def atlas(n, spacing):
        if n <= 0:
            return ''
        corner = (walk(spacing)+'l'+walk(spacing)+'r'+atlas(n-1, spacing-3)
                  +'r'+walk(spacing)+'r'+walk(spacing)+'r')
        return corner*4

    add((12, 12), atlas(3, 7), WALK+FOUR+
        'c(N,S):b(S)lb(S)ra(N-1,S-3)rb(S)rb(S)r\na(N,S):q(c(N,S))\na(3,7)')

    def dragon(n, which='a', step='ss'):
        if n == 0:
            return ''
        if which == 'a':
            return dragon(n-1, 'a', step)+'r'+dragon(n-1, 'c', step)+step+'r'
        return 'l'+step+dragon(n-1, 'a', step)+'l'+dragon(n-1, 'c', step)

    commands = 'ss'+dragon(6)
    # Center this asymmetric fold without rotating its required north-facing start.
    path = [(0, 0), *trace((0, 0), commands, bounded=False)]
    xs, ys = zip(*path)
    start = ((24-max(xs)-min(xs))//2, (24-max(ys)-min(ys))//2)
    add(start, commands, 'a(N):a(N-1)rc(N-1)ssr\nc(N):lssa(N-1)lc(N-1)\nssa(6)')

    trip = 's'+dragon(5, step='s')
    inverse = ''.join({'s': 's', 'r': 'l', 'l': 'r'}[c] for c in trip[::-1])
    add((12, 12), (trip+'rr'+inverse+'rrr')*4,
        'a(N):a(N-1)rc(N-1)sr\nc(N):lsa(N-1)lc(N-1)\n'
        'd(N):lsf(N-1)ld(N-1)\nf(N):f(N-1)rd(N-1)sr\n'
        'e:sa(5)rrd(5)srrr\neeee')

    def canopy(n, distance, turn, courtyard=False):
        if n <= 0:
            return ''
        opposite = 'rr'+turn
        return ((square(distance) if courtyard else '')+walk(distance)+turn
                +canopy(n-1, distance-2, opposite, courtyard)+'rr'
                +canopy(n-1, distance-2, turn, courtyard)+turn+'rr'+walk(distance)+'rr')

    add((12, 12), (canopy(4, 7, 'r')+'r')*4, WALK+FOUR+
        'a(N,D,T):b(D)Ta(N-1,D-2,rrT)rra(N-1,D-2,T)Trrb(D)rr\nq(a(4,7,r)r)')

    def vault_row(n, w):
        if n <= 0:
            return ''
        return square(w)+'r'+walk(w+1)+'l'+vault_row(n-1, w)+'l'+walk(w+1)+'r'

    def vault(n, w):
        if n <= 0:
            return ''
        return vault_row(n, w)+walk(w+2)+vault(n-1, w-1)+'rr'+walk(w+2)+'rr'

    add((12, 12), (vault(3, 3)+'r')*4, WALK+FOUR+
        'd(W):q(b(W)r)\nc(N,W):d(W)rb(W+1)lc(N-1,W)lb(W+1)r\n'
        'a(N,W):c(N,W)b(W+2)a(N-1,W-1)rrb(W+2)rr\nq(a(3,3)r)')

    add((12, 12), (canopy(3, 6, 'r', courtyard=True)+'r')*4, WALK+FOUR+
        'd(W):q(b(W)r)\na(N,D,T):d(D)b(D)Ta(N-1,D-2,rrT)rra(N-1,D-2,T)Trrb(D)rr\nq(a(3,6,r)r)')
    assert len(result) == len(LESSONS) == 20
    return result
