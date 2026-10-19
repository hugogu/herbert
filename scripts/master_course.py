"""Master geometric course: 10 harder problems (L31–L40)."""
from advanced_course import LESSONS as ADVANCED_LESSONS, advanced_designs, walk, square, WALK, FOUR
from open_course import landmarks, orbit

CHAPTERS = [
    ('Advanced fractal topology', '高阶分形拓扑', '高次フラクタル幾何'),
    ('Grandmaster recursive synthesis', '终极递归与算法综合', '超高難度再帰と総合設計'),
]


def lesson(title, goal, observation, strategy):
    return (title, goal, [observation, strategy])


LESSONS = ADVANCED_LESSONS + [
    # L31
    lesson(('Moore\'s nexus', '摩尔回路', 'ムーアの環'),
           ('Weave a closed space-filling loop across four quadrants by linking rotated Hilbert quarters.',
            '通过连接四个旋转的希尔伯特子象限，织出贯穿四个象限的闭合空间填充环。',
            '回転させた四つのヒルベルト曲線を結び、四象限を巡る閉じた空間充填ループを織ろう。'),
           ('Unlike the open Hilbert curve where start and end lie in opposite corners, the Moore curve forms an unbroken closed loop with 4-fold rotational symmetry returning to its origin.',
            '与首尾位于对角的开放希尔伯特曲线不同，摩尔曲线构成四向对称的闭合回路，最终回到起点。',
            '始点と終点が対角にあるヒルベルト曲線とは異なり、ムーア曲線は四回対称の閉じた環となり元の位置へ戻ります。'),
           ('Factor a recursive Hilbert subcurve with turn-swapping, then embed it into a fourfold repeater with connector links.',
            '提取交换转向的递归希尔伯特子曲线，将其嵌入带有连接步的四次重复器中。',
            '回転を入れ替える再帰ヒルベルト曲線を抽出し、接続歩数とともに四回反復手続きへ埋め込みましょう。')),

    # L32
    lesson(('Twin dragon bough', '双生龙纹', '双子の竜紋'),
           ('Traverse two interlocking fractal dragon arms with 180-degree point symmetry.',
            '遍历两组具有 180 度中心对称的相互嵌套分形龙纹。',
            '180度の点対称を持つ二組の自己相似な竜紋を巡ろう。'),
           ('The board exhibits pure 2-fold central inversion symmetry: every feature in the northern quadrant has an identical counterpart rotated 180 degrees into the southern quadrant.',
            '棋盘呈现严格的 2 阶中心反演对称：北侧的每一个分支在 180 度旋转后都能在南侧找到对应结构。',
            '盤面は厳密な二回点対称を持ちます：北側の構造は180度回転すると南側にそのまま対応します。'),
           ('Build an asymmetric tree arm with dynamic turn inversion rrT, then pass it as an embedded argument to a two-fold inverter procedure.',
            '构造带动态转向反转 rrT 的非对称树枝，然后将其作为参数嵌入二阶反演过程中。',
            '動的回転反転 rrT を持つ非対称な枝を作り、二回反転手続きへ引数として埋め込みましょう。')),

    # L33
    lesson(('Mirrored canopy', '双翼神木', '双翼の神樹'),
           ('Generate a bilateral fractal canopy with pure vertical mirror symmetry across the central axis.',
            '沿中央轴线生成左右完美镜面对称的双翼分形树冠。',
            '中央軸に対して完全な左右線対称を持つ双翼のフラクタル樹冠を生成しよう。'),
           ('The pattern possesses exact bilateral reflection symmetry: the left wing is a mirror reflection of the right wing across the vertical line x=12.',
            '图案具有严格的轴对称（镜面对称）：左侧羽翼是右侧羽翼关于垂直轴 x=12 的完美镜面反射。',
            '模様は厳密な左右線対称を持ちます：左の翼は垂直軸 x=12 を挟んで右の翼と鏡映になっています。'),
           ('Define a recursive branching arm, then pass mirrored calls with opposing chiral turns into a higher-order dual dispatcher.',
            '定义递归分枝过程，把相反旋向的两个调用作为实参嵌入高阶双路分发器中。',
            '再帰的な分岐手続きを定義し、左右逆の回転を渡した二つの呼び出しを高階手続きへ埋め込みましょう。')),

    # L34
    lesson(('Peano meander', '皮亚诺回廊', 'ペアノの迷路'),
           ('Traverse a space-filling serpentine meander spanning four symmetric quadrants.',
            '遍历贯穿四个对称象限的蛇形空间填充回廊。',
            '四つの対称な象限を巡る蛇行空間充填回廊を走破しよう。'),
           ('The nested serpentine meander divides space recursively, preserving 4-fold rotational symmetry around the center.',
            '嵌套蛇形回廊对空间进行递归细分，围绕中心严格保持四向旋转对称。',
            '入れ子状の蛇行回廊は空間を再帰的に細分し、中心の周りで四回回転対称を保ちます。'),
           ('Compose serpentine folds with inward parameter decay, and drive it through an embedded call inside a fourfold repeater.',
            '构造带有步长衰减的蛇形折叠，并作为嵌入调用传入四次重复器中驱动。',
            '歩数を減らす蛇行折れ曲がりを組み立て、四回反復の中の埋め込み呼び出しで実行しましょう。')),

    # L35
    lesson(('Koch snowflake star', '科赫雪晶', '雪晶の星陣'),
           ('Synthesize an 8-fold dihedral fractal snowflake star with multi-level triangular promontories.',
            '合成具有 8 阶二面体对称的多级三角形科赫雪花星阵。',
            '八面体対称を持つ多段の三角形コッホ雪片星陣を合成しよう。'),
           ('The snowflake exhibits full 8-fold dihedral symmetry (D4), combining 4-fold rotation with diagonal and axial reflections.',
            '雪花呈现完整的 8 阶二面体对称（D4），同时兼具四向旋转与轴向/对角镜面对称。',
            '雪片は完全な八面体対称（D4）を示し、四回回転に対角・軸対称が重なっています。'),
           ('Branch each arm recursively into dual sub-arms with opposite chiral turns, then wrap in an embedded fourfold dispatcher.',
            '让每条射线递归分裂为旋向相反的孪生子分支，再嵌入四向分发器中。',
            '各光線を逆向きの二つの小枝へと再帰分岐させ、四回分発手続きへ埋め込んで包みましょう。')),

    # L36
    lesson(('Fibonacci bough', '斐波那契分枝', 'フィボナッチの樹'),
           ('Master asymmetric tree recursion: traverse unbalanced N-1 and N-2 subtrees and restore caller pose.',
            '攻克非对称树状递归：分别遍历深度为 N-1 与 N-2 的子树，并严格复原父级姿态。',
            '非対称な樹状再帰を習得しよう：深さ N-1 と N-2 の異なる部分木を巡り、親の状態へ完全に復帰しよう。'),
           ('A Fibonacci tree branches with different decay rates: the left branch recurses with N-1 while the right recurses with N-2.',
            '斐波那契树两侧分支缩减速度不同：左支递归 N-1，右支递归 N-2。',
            'フィボナッチ木は左右で減衰速度が異なり、左は N-1、右は N-2 で再帰します。'),
           ('The return path cannot mirror a uniform child. Explicitly retrace distance D after both subtrees finish, wrapped in an embedded call.',
            '返回路径不能依赖对称镜像；在 N-1 和 N-2 子分支均完成后，倒序折返距离 D，嵌入四向重复器。',
            '戻り道は対称になりません。両方の枝の後で距離 D を引き返し、四回反復へ埋め込みましょう。')),

    # L37
    lesson(('Dual-rate pendulum', '双频谐振晶格', '複動の振り子'),
           ('Interleave two independent clock frequencies to weave a poly-periodic harmonic lattice.',
            '耦合两组独立时钟频率，编织多周期双频谐振晶格。',
            '二つの独立した周期を連動させ、多重周期の調和格子を織り上げよう。'),
           ('Two counters decrementing at different rates trigger staggered termination conditions while preserving exact return invariants.',
            '两个按不同速率衰减的计步器触发交错的终止条件，同时精确保持原路折返不变量。',
            '異なる速度で減る二つの計数引数が互い違いの終了を起こしつつ、正確な引き返し条件を保ちます。'),
           ('Maintain dual parameters A and B with chiral turn inversion, retrace along the conjugate path, and embed in a fourfold repeater.',
            '维护双参数 A 与 B 及手性转向反转，沿共轭路径折返，并嵌入四向重复器中。',
            '引数 A と B および回転反転を保ち、共役な経路で引き返して、四回反復へ埋め込みましょう。')),

    # L38
    lesson(('Hanoi ribbon', '汉诺织带', 'ハノイの織帯'),
           ('Execute a binary reflected Gray code sequence, recursing through inner chambers before each pivot step.',
            '执行二进制反射格雷码序列，在每个枢轴步进前递归遍历内层回路。',
            '二進反射グレイコードの順序に従い、軸となる前進の前に内部ループを再帰走破しよう。'),
           ('The classic Tower of Hanoi sequence visits states without redundant passes: G(N) expands into G(N-1), step, G(N-1).',
            '经典的汉诺塔序列无冗余遍历状态：G(N) 展开为 G(N-1)、主前进步、G(N-1)。',
            'ハノイの塔の数列は重複なく状態を巡ります：G(N) は G(N-1)、前進、G(N-1) へ展開されます。'),
           ('Procedure g(N, T) calls g(N-1, rrT), advances b(N), executes turn T, calls g(N-1, T), and unwinds b(N), embedded in a dispatcher.',
            '过程 g(N, T) 先调用 g(N-1, rrT)，前进 b(N)，转向 T，再调用 g(N-1, T)，最后折返 b(N)，嵌入分发器中。',
            '手続き g(N, T) は g(N-1, rrT) を呼び、b(N) 進んで T を曲がり、g(N-1, T) を呼び、b(N) を戻る処理を埋め込みましょう。')),

    # L39
    lesson(('Octagram mandala', '八荒星阵', '八荒の星曼荼羅'),
           ('Harmonize cardinal steps and diagonal staircase walkers across three concentric octagonal tiers with 8-fold dihedral symmetry.',
            '融合轴向直行与对角阶梯步进，以完整的 8 阶二面体对称贯穿三层同心八角星阵。',
            '直線歩行と対角階段歩行を調和させ、完全な八面体対称で三重の同心八角星陣を巡ろう。'),
           ('Four cardinal spokes and four diagonal stair rays radiate simultaneously, creating an 8-fold dihedral (D4) star polygon.',
            '四条轴向辐条与四条对角阶梯射线同时向外辐射，构成 8 阶二面体对称（D4）的星多边形。',
            '四本の主軸と四本の対角階段が同時に広がり、八面体対称（D4）の星形多角形を形成します。'),
           ('Pair cardinal walk b(S) with diagonal stair d(N), retrace each symmetrically, and invoke via mutually recursive embedded dispatcher a(N,S):q(m(N,S)r).',
            '组合轴向步行 b(S) 与对角阶梯 d(N) 并对称折返，通过相互递归的嵌入分发器 a(N,S):q(m(N,S)r) 调用。',
            '直線 b(S) と対角階段 d(N) を組んで引き返し、相互再帰の埋め込み手続き a(N,S):q(m(N,S)r) で呼び出しましょう。')),

    # L40
    lesson(('Celestial armillary', '终焉星仪', '終局の天球儀'),
           ('Synthesize concentric courtyards, asymmetric Fibonacci spires, and orbital rotations into a grandmaster capstone.',
            '综合同心庭院、非对称斐波那契分枝与轨道旋转，铸就终极星仪。',
            '同心の庭、非対称フィボナッチの樹、軌道回転を統合し、終局の天球儀を完成させよう。'),
           ('Four quadrants each contain a courtyard chamber and an unbalanced asymmetric recursive spire branching into deep space.',
            '四个象限各包含一个庭院腔室和一束延伸至深处的非对称递归分枝树。',
            '四つの象限のそれぞれに四角い庭と、外側へ伸びる非对称な再帰の樹があります。'),
           ('Compose courtyard generator c(W), Fibonacci tree f(N, D, T), and sector orchestrator a(N, D, T), driven by an embedded call inside repeater q.',
            '组合庭院生成器 c(W)、斐波那契树 f(N, D, T) 与扇区总控 a(N, D, T)，由重复器 q 内的嵌入调用驱动。',
            '庭 c(W)、フィボナッチの樹 f(N, D, T)、区画統括 a(N, D, T) を組み合わせ、反復 q 内の埋め込み呼び出しで駆動しましょう。')),
]


def master_designs(trace):
    result = advanced_designs(trace)

    def add(start, commands, source, wall_motif, trap_motif, symmetry=4):
        route = {start, *trace(start, commands)}
        protected = orbit(route, symmetry) if symmetry > 1 else set(route)
        walls, traps = landmarks(protected, wall_motif, trap_motif, symmetry=symmetry)
        result.append((start, commands, source, sorted(route - {start}), walls, traps))

    # L31: Moore's nexus (D4 8-fold dihedral / C4)
    def hilbert(n, x='r', y='l'):
        if n == 0: return ''
        return (x+hilbert(n-1, y, x)+'ss'+y+hilbert(n-1, x, y)+'ss'
                +hilbert(n-1, x, y)+y+'ss'+hilbert(n-1, y, x)+x)

    add((8, 16), (hilbert(2)+'ssr')*4,
        WALK + FOUR + 'a(N,X,Y):Xa(N-1,Y,X)b(2)Ya(N-1,X,Y)b(2)a(N-1,X,Y)Yb(2)a(N-1,Y,X)X\nq(a(2,r,l)b(2)r)',
        wall_motif={(15, 11), (17, 13), (17, 15)},
        trap_motif={(11, 7), (13, 13), (7, 14)},
        symmetry=4)

    # L32: Twin dragon bough (C2 180-deg central inversion symmetry)
    def fib_bough(n, d, t='r'):
        if n <= 0 or d <= 0: return ''
        return walk(d) + t + fib_bough(n-1, d-2, 'rr'+t) + 'rr' + fib_bough(n-2, d-3, t) + t + 'rr' + walk(d) + 'rr'

    add((12, 12), fib_bough(4, 7, 'r') + 'rr' + fib_bough(4, 7, 'r') + 'rr',
        WALK + 'h(P):PrrPrr\nf(N,D,T):b(D)Tf(N-1,D-2,rrT)rrf(N-2,D-3,T)Trrb(D)rr\nh(f(4,7,r))',
        wall_motif={(11, 8), (11, 9), (11, 10), (11, 11), (11, 12), (11, 13), (11, 14), (11, 15), (11, 16)},
        trap_motif={(7, 16), (10, 6), (10, 18), (11, 6), (11, 7), (11, 17), (11, 18), (12, 4)},
        symmetry=2)

    # L33: Mirrored canopy (D1 bilateral mirror symmetry across x=12)
    add((12, 19), fib_bough(4, 7, 'r') + fib_bough(4, 7, 'l'),
        WALK + 'm(P,Q):PQ\nf(N,D,T):b(D)Tf(N-1,D-2,rrT)rrf(N-2,D-3,T)Trrb(D)rr\nm(f(4,7,r),f(4,7,l))',
        wall_motif={(9, 11), (10, 11), (10, 13), (11, 10), (11, 11), (11, 13), (11, 14)},
        trap_motif={(9, 10), (9, 13), (9, 14), (11, 8), (11, 9), (11, 15)},
        symmetry=2)

    # L34: Peano meander (C4 serpentine meander)
    def peano_meander(n, s):
        if n <= 0 or s <= 0: return ''
        return walk(s) + 'r' + walk(s) + 'l' + walk(s) + peano_meander(n-1, s-2) + 'rr' + walk(s) + 'r' + walk(s) + 'l' + walk(s) + 'rr'

    add((12, 12), (peano_meander(2, 3) + 'r') * 4,
        WALK + FOUR + 'p(N,S):b(S)rb(S)lb(S)p(N-1,S-2)rrb(S)rb(S)lb(S)rr\nq(p(2,3)r)',
        wall_motif={(8, 12), (10, 11), (10, 13), (11, 11)},
        trap_motif={(8, 11), (9, 13), (9, 14), (10, 10)},
        symmetry=4)

    # L35: Koch snowflake star (D4 8-fold dihedral)
    def koch_arm(n, d):
        if n <= 0 or d <= 0: return ''
        child = 'l' + koch_arm(n-1, d-2) + 'rr' + koch_arm(n-1, d-2) + 'l'
        return walk(d) + child + 'rr' + walk(d) + 'rr'

    add((12, 12), (koch_arm(3, 6) + 'r') * 4,
        WALK + FOUR + 'k(N,D):b(D)lk(N-1,D-2)rrk(N-1,D-2)lrrb(D)rr\nq(k(3,6)r)',
        wall_motif={(8, 11), (8, 13), (9, 11), (9, 13), (10, 11), (10, 13), (11, 11)},
        trap_motif={(5, 12), (7, 10), (7, 11), (7, 13), (7, 14), (8, 9)},
        symmetry=4)

    # L36: Fibonacci bough (C4 with internal asymmetric tree)
    add((12, 12), (fib_bough(4, 6, 'r') + 'r') * 4,
        WALK + FOUR + 'a(N,D,T):b(D)Ta(N-1,D-2,rrT)rra(N-2,D-3,T)Trrb(D)rr\nq(a(4,6,r)r)',
        wall_motif={(8, 11), (9, 11), (9, 13), (10, 11), (10, 13), (11, 11)},
        trap_motif={(5, 12), (7, 10), (7, 11), (7, 13), (8, 13)},
        symmetry=4)

    # L37: Dual-rate harmonic pendulum (C4 poly-periodic harmonic lattice)
    def dual_pendulum(a, b, t='r'):
        if a <= 0 or b <= 0: return ''
        child = dual_pendulum(a-1, b-2, 'rr'+t)
        return walk(a) + t + walk(b) + t + child + t + walk(b) + 'rr'+t + walk(a) + 'rr'

    add((12, 12), (dual_pendulum(3, 4, 'r') + 'r') * 4,
        WALK + FOUR + 'p(A,B,T):b(A)Tb(B)Tp(A-1,B-2,rrT)Tb(B)rrTb(A)rr\nq(p(3,4,r)r)',
        wall_motif={(10, 11), (10, 13), (11, 11)},
        trap_motif={(8, 12), (9, 13), (10, 10)},
        symmetry=4)

    # L38: Hanoi ribbon (C4 binary reflected Gray code)
    def hanoi_g(n, t='r'):
        if n <= 0: return ''
        return hanoi_g(n-1, 'rr'+t) + walk(n) + t + hanoi_g(n-1, t) + t + 'rr' + walk(n) + 'rr'

    add((12, 12), (hanoi_g(4, 'r') + 'r') * 4,
        WALK + FOUR + 'g(N,T):g(N-1,rrT)b(N)Tg(N-1,T)Trrb(N)rr\nq(g(4,r)r)',
        wall_motif={(8, 9), (11, 17)},
        trap_motif={(11, 7), (16, 8)},
        symmetry=4)

    # L39: Octagram mandala (D4 8-fold dihedral)
    def oct_stair(n): return 'srsl' * n
    def mandala_quad(s, n):
        return 's'*s + 'rr' + 's'*s + 'rr' + oct_stair(n) + 'rr' + oct_stair(n) + 'rr'

    add((12, 12), (mandala_quad(6, 4) + 'r') * 4,
        WALK + FOUR + 'd(N):srsld(N-1)\nm(S,N):b(S)rrb(S)rrd(N)rrd(N)rr\na(S,N):q(m(S,N)r)\na(6,4)',
        wall_motif={(8, 11), (9, 11), (9, 13)},
        trap_motif={(7, 11), (7, 13), (8, 13)},
        symmetry=4)

    # L40: Celestial armillary (C4 Grandmaster synthesis)
    def armillary_f(n, d, t='r'):
        if n <= 0 or d <= 0: return ''
        return walk(d) + t + armillary_f(n-1, d-2, 'rr'+t) + 'rr' + armillary_f(n-2, d-3, t) + t + 'rr' + walk(d) + 'rr'
    def armillary_a(n, d, t='r'):
        return square(d) + armillary_f(n, d, t) + 'r'

    add((12, 12), armillary_a(3, 5, 'r') * 4,
        WALK + FOUR + 'c(W):q(b(W)r)\nf(N,D,T):b(D)Tf(N-1,D-2,rrT)rrf(N-2,D-3,T)Trrb(D)rr\na(N,D,T):c(D)f(N,D,T)r\nq(a(3,5,r))',
        wall_motif={(9, 11), (9, 13), (10, 11), (10, 13), (11, 11)},
        trap_motif={(6, 12), (8, 10), (8, 11), (8, 13)},
        symmetry=4)

    assert len(result) == len(LESSONS) == 30
    return result
