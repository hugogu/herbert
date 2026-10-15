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
           ('Unlike the Hilbert curve where start and end lie in opposite corners, the Moore curve forms an unbroken closed loop returning to its initial position.',
            '与首尾位于对角的希尔伯特曲线不同，摩尔曲线构成闭合回路，最终回到起点。',
            '始点と終点が対角にあるヒルベルト曲線とは異なり、ムーア曲線は途切れない閉じた環となり元の位置へ戻ります。'),
           ('Factor a recursive Hilbert subcurve with turn-swapping, then join four copies with two-step connector bridges and a quarter-turn repeater.',
            '提取交换转向的递归希尔伯特子曲线，用两格连接线把四份子曲线拼合，再用四分之一次旋转重复器闭合。',
            '回転を入れ替える再帰ヒルベルト曲線を抽出し、二マスの接続線で四区画をつなぎ、四分の一回転反復で閉じましょう。')),

    # L32
    lesson(('Terdragon spine', '三叉龙脊', '三叉竜の迷宮'),
           ('Expand a 3-way branching fractal curve on a Manhattan grid using alternating chiral turns.',
            '在曼哈顿网格上展开三叉分形曲线，交替改变手性转向。',
            'マンハッタン格子上で三つに分岐するフラクタル曲線を展開し、回転方向を交互に変えよう。'),
           ('The Heighway dragon splits each unit into two segments; the Terdragon curve splits each unit into three sub-segments.',
            '常规龙形折线将单元一分为二；三叉龙形曲线则将每个单元分裂为三段。',
            '通常のドラゴン曲線は二つに分かれますが、三叉竜は各区間を三つの部分に分割します。'),
           ('Let procedure a(N,T) invoke three subcalls: first with inverted turn rrT, middle with T, and third with rrT.',
            '让过程 a(N,T) 执行三次子调用：首尾使用反转转向 rrT，中间使用原始转向 T。',
            '手続き a(N,T) で三回呼び出します。最初と最後は反転した rrT、中間は元の T を使いましょう。')),

    # L33
    lesson(('Sierpinski arrowhead', '角晶罗网', '矢のフラクタル'),
           ('Generate an orthogonal Sierpinski gasket using dual mutually recursive diagonal walkers.',
            '利用相互递归的双对角步进过程，在直角网格上生成谢尔宾斯基三角网。',
            '相互再帰する二つの斜め歩行手続きを用い、直角格子上にシェルピンスキーの三角形を描こう。'),
           ('The arrowhead curve creates a triangular fractal gasket on a square grid by substituting straight segments with diagonal staircase steps.',
            '箭头曲线在方格网格上用斜向阶梯代替斜线，构造出自相似的三角形分形网。',
            '矢頭曲線は直角格子上で斜めの階段を用いて斜線を表し、自己相似の三角形フラクタルを描きます。'),
           ('Use two procedures that exchange parameter roles and turns, then rotate fourfold.',
            '使用两个过程交替传递参数角色与转向，走完后进行四向旋转。',
            '二つの手続きで引数の役割と回転方向を交互に渡し、四方向に回転させましょう。')),

    # L34
    lesson(('Peano tapestry', '皮亚诺织锦', 'ペアノの迷路'),
           ('Traverse a 3x3 space-filling serpentine meander with nested shrinking corridors.',
            '利用嵌套缩小的回廊结构，遍历 3x3 的蛇形空间填充曲线。',
            '入れ子状に縮む回廊を用い、3x3 の蛇行する空間充填曲線を走破しよう。'),
           ('The Peano curve divides each square into nine smaller squares, requiring alternating row and column serpentine folds.',
            '皮亚诺曲线将每个方格划分为九个更小的方格，需要交替进行行与列的蛇形迂回。',
            'ペアノ曲線は正方形を九つの小正方形に分割し、行と列を交互に蛇行して巡ります。'),
           ('Build a serpentine unit with step parameter S, recurse inward with S-2, and wrap in a 4-fold rotation repeater.',
            '用步长参数 S 构造蛇形单元，以 S-2 向内递归，并用四向旋转重复器封装。',
            '歩数引数 S で蛇行単位を作り、S-2 で内側へ再帰して、四回反復で囲みましょう。')),

    # L35
    lesson(('Gosper island', '高斯帕星岛', 'ゴスパーの島'),
           ('Grow a multi-scale fractal coastline using string expansion, filtering out shallower layers with a numeric guard.',
            '通过指令字符串递归展开分形海岸线，并用数值守卫滤去浅层展开。',
            '命令列の再帰展開でフラクタル海岸線を育て、数値条件で浅い階層をスキップしよう。'),
           ('The boundary of the Flowsnake fractal exhibits self-similar bays and promontories at multiple scales.',
            '流动蛇分形的边界在不同尺度上呈现自相似的海湾与岬角。',
            'フロウスネーク・フラクタルの輪郭は、複数の縮尺で自己相似の湾と岬を描きます。'),
           ('Expand motif X to XrXllXrX recursively; guard the execution line with c(2-N, X) so only the deepest expansion fires.',
            '递归展开 X 为 XrXllXrX，用 c(2-N, X) 守卫执行，确保只触发最深层的展开结果。',
            'X を XrXllXrX へ再帰展開し、c(2-N, X) で最深の展開のみを実行させましょう。')),

    # L36
    lesson(('Fibonacci bough', '斐波那契分枝', 'フィボナッチの樹'),
           ('Master asymmetric tree recursion: traverse unbalanced N-1 and N-2 subtrees and restore the caller pose.',
            '攻克非对称树状递归：分别遍历深度为 N-1 与 N-2 的子树，并严格复原父级姿态。',
            '非対称な樹状再帰を習得しよう：深さ N-1 と N-2 の異なる部分木を巡り、親の状態へ完全に復帰しよう。'),
           ('A Fibonacci tree branches with different decay rates: the left branch recurses with N-1 while the right recurses with N-2.',
            '斐波那契树两侧分支缩减速度不同：左支递归 N-1，右支递归 N-2。',
            'フィボナッチ木は左右で減衰速度が異なり、左は N-1、右は N-2 で再帰します。'),
           ('The return path cannot mirror a uniform child. Explicitly retrace distance D after both the N-1 child and the N-2 child finish.',
            '返回路径不能依赖对称镜像；在 N-1 和 N-2 子分支均完成后，明确按原距离 D 折返。',
            '戻り道は対称になりません。N-1 と N-2 の両方の枝が終わった後、距離 D を明示的に引き返しましょう。')),

    # L37
    lesson(('Dual-rate pendulum', '双频谐振', '複動の振り子'),
           ('Interleave two independent clock frequencies to weave a poly-periodic harmonic lattice.',
            '耦合两组独立时钟频率，编织多周期双频谐振晶格。',
            '二つの独立した周期を連動させ、多重周期の調和格子を織り上げよう。'),
           ('Two counters decrementing at different rates trigger staggered termination conditions.',
            '按不同速度衰减的两个计数器会触发交错的终止条件。',
            '異なる速度で減る二つの計数引数が、互い違いの終了条件を引き起こします。'),
           ('Maintain dual parameters A and B, alternating between fast-decaying and slow-decaying axes, retracing b(A) upon return.',
            '维护双参数 A 与 B，在快衰减轴与慢衰减轴之间交替切换，返回时折返 b(A)。',
            '引数 A と B を保持し、減りの速い軸と遅い軸を切り替え、戻り時に b(A) を引き返しましょう。')),

    # L38
    lesson(('Hanoi ribbon', '汉诺织带', 'ハノイの織帯'),
           ('Execute a binary reflected Gray code sequence, recursing through inner chambers before each pivot step.',
            '执行二进制反射格雷码序列，在每个枢轴步进前递归遍历内层回路。',
            '二進反射グレイコードの順序に従い、軸となる前進の前に内部ループを再帰走破しよう。'),
           ('The classic Tower of Hanoi sequence visits states without redundant passes: G(N) expands into G(N-1), step, G(N-1).',
            '经典的汉诺塔序列无冗余遍历状态：G(N) 展开为 G(N-1)、主前进步、G(N-1)。',
            'ハノイの塔の数列は重複なく状態を巡ります：G(N) は G(N-1)、前進、G(N-1) へ展開されます。'),
           ('Procedure g(N, T) calls g(N-1, rrT), advances b(N), executes turn T, calls g(N-1, T), and unwinds b(N).',
            '过程 g(N, T) 先调用 g(N-1, rrT)，前进 b(N)，转向 T，再调用 g(N-1, T)，最后折返 b(N)。',
            '手続き g(N, T) は g(N-1, rrT) を呼び、b(N) 進んで T を曲がり、g(N-1, T) を呼び、b(N) を戻ります。')),

    # L39
    lesson(('Octagram mandala', '八荒星阵', '八荒の星曼荼羅'),
           ('Harmonize cardinal steps and diagonal staircase walkers across three concentric octagonal tiers.',
            '融合轴向直行与对角阶梯步进，贯穿三层同心八角星阵。',
            '直線歩行と対角階段歩行を調和させ、三重の同心八角星陣を巡ろう。'),
           ('Cardinal moves and diagonal staircase moves displace differently; combining them with 8-fold dihedral symmetry requires decoupled counters.',
            '轴向移动与斜向阶梯位移不同；结合八向对称需要解耦两个计步器。',
            '直線と斜め階段は移動量が異なります。八方向の対称性に合わせるため、二つの歩数を独立させましょう。'),
           ('Define d(N) for diagonal stair stepping, combine cardinal b(S) with d(N), recurse inward with S-2, and undo via rrd(N)rrb(S)rr.',
            '定义斜向阶梯 d(N)，将轴向 b(S) 与 d(N) 结合，以 S-2 向内递归，并通过 rrd(N)rrb(S)rr 折返。',
            '階段 d(N) を定義し、直線の b(S) と組み合わせ、S-2 で内側へ再帰し、rrd(N)rrb(S)rr で引き返しましょう。')),

    # L40
    lesson(('Celestial armillary', '终焉星仪', '終局の天球儀'),
           ('Synthesize concentric courtyards, asymmetric Fibonacci spires, and orbital rotations into a grandmaster capstone.',
            '综合同心庭院、非对称斐波那契分枝与轨道旋转，铸就终极星仪。',
            '同心の庭、非対称フィボナッチの樹、軌道回転を統合し、終局の天球儀を完成させよう。'),
           ('Four quadrants each contain a courtyard chamber and an unbalanced asymmetric recursive spire branching into deep space.',
            '四个象限各包含一个庭院腔室和一束延伸至深处的非对称递归分枝树。',
            '四つの象限のそれぞれに四角い庭と、外側へ伸びる非対称な再帰の樹があります。'),
           ('Compose three procedures: courtyard generator c(W), asymmetric Fibonacci tree f(N, D, T), and sector orchestrator a(N, D, T) wrapped in a 4-fold dispatcher.',
            '组合三个过程：庭院生成器 c(W)、非对称树 f(N, D, T) 与扇区总控 a(N, D, T)，交由四次重复器驱动。',
            '庭 c(W)、非対称の樹 f(N, D, T)、区画の統括 a(N, D, T) の三つを組み立て、四回反復で実行しましょう。')),
]


def master_designs(trace):
    result = advanced_designs(trace)

    def add(start, commands, source, wall_motif, trap_motif, symmetry=4):
        route = {start, *trace(start, commands)}
        protected = orbit(route, symmetry) if symmetry > 1 else set(route)
        walls, traps = landmarks(protected, wall_motif, trap_motif, symmetry=symmetry)
        result.append((start, commands, source, sorted(route - {start}), walls, traps))

    # L31
    def hilbert(n, x='r', y='l'):
        if n == 0: return ''
        return (x+hilbert(n-1, y, x)+'ss'+y+hilbert(n-1, x, y)+'ss'
                +hilbert(n-1, x, y)+y+'ss'+hilbert(n-1, y, x)+x)

    add((8, 16), (hilbert(2)+'ssr')*4,
        WALK + FOUR + 'a(N,X,Y):Xa(N-1,Y,X)b(2)Ya(N-1,X,Y)b(2)a(N-1,X,Y)Yb(2)a(N-1,Y,X)X\nq(a(2,r,l)b(2)r)',
        wall_motif={(15, 11), (17, 13), (17, 15)},
        trap_motif={(11, 7), (13, 13), (7, 14)},
        symmetry=4)

    # L32
    def terdragon(n, t='r'):
        if n <= 0: return ''
        return terdragon(n-1, 'rr'+t) + 'ss' + t + terdragon(n-1, t) + 'ss' + 'rr'+t + terdragon(n-1, 'rr'+t)

    add((9, 17), terdragon(3, 'r'),
        WALK + 'a(N,T):a(N-1,rrT)b(2)Ta(N-1,T)b(2)rrTa(N-1,rrT)\na(3,r)',
        wall_motif={(13, 14), (16, 10), (10, 9), (8, 17), (10, 14), (13, 6), (14, 12), (10, 12), (12, 14)},
        trap_motif={(9, 10), (12, 7), (14, 10), (18, 9), (10, 16), (9, 18), (15, 6), (15, 12), (16, 11)},
        symmetry=1)

    # L33
    def arrowhead_a(n, x='r', y='l'):
        if n <= 0: return ''
        return arrowhead_c(n-1, y, x) + 's' + x + arrowhead_a(n-1, x, y) + y + 's'

    def arrowhead_c(n, x='r', y='l'):
        if n <= 0: return ''
        return arrowhead_a(n-1, y, x) + 's' + y + arrowhead_c(n-1, x, y) + x + 's'

    add((7, 12), (arrowhead_a(3, 'r', 'l') + 'r') * 4,
        WALK + FOUR + 'a(N,X,Y):c(N-1,Y,X)b(1)Xa(N-1,X,Y)Yb(1)\nc(N,X,Y):a(N-1,Y,X)b(1)Yc(N-1,X,Y)Xb(1)\nq(a(3,r,l)r)',
        wall_motif={(5, 10), (10, 12), (14, 15)},
        trap_motif={(15, 20), (10, 4), (15, 14)},
        symmetry=4)

    # L34
    def peano_c(n, s):
        if n <= 0: return ''
        return walk(s) + 'r' + walk(s) + 'l' + walk(s) + 'r' + (peano_c(n-1, s-2) * 4 if n > 1 else '') + 'r' + walk(s) + 'l' + walk(s) + 'r'

    add((12, 12), peano_c(2, 3) * 4,
        WALK + FOUR + 'c(N,S):b(S)rb(S)lb(S)ra(N-1,S-2)rb(S)lb(S)r\na(N,S):q(c(N,S))\na(2,3)',
        wall_motif={(11, 18), (13, 8), (9, 19), (14, 6)},
        trap_motif={(13, 7), (7, 13), (14, 16), (6, 17)},
        symmetry=4)

    # L35
    motif = 'ss'
    for _ in range(2):
        motif = motif + 'r' + motif + 'll' + motif + 'r' + motif

    add((12, 12), (motif + 'r') * 4,
        'a(N,X):a(N-1,XrXllXrX)c(2-N,X)\nc(N,X):XrXrXrXr\na(3,ss)',
        wall_motif={(7, 7), (19, 7), (3, 7), (21, 12), (18, 3), (9, 5), (11, 11)},
        trap_motif={(3, 8), (21, 13), (9, 21), (13, 9), (5, 19), (7, 15), (21, 11)},
        symmetry=4)

    # L36
    def fib_bough(n, d, t='r'):
        if n <= 0 or d <= 0: return ''
        return walk(d) + t + fib_bough(n-1, d-2, 'rr'+t) + 'rr' + fib_bough(n-2, d-3, t) + t + 'rr' + walk(d) + 'rr'

    add((12, 12), (fib_bough(4, 6, 'r') + 'r') * 4,
        WALK + FOUR + 'a(N,D,T):b(D)Ta(N-1,D-2,rrT)rra(N-2,D-3,T)Trrb(D)rr\nq(a(4,6,r)r)',
        wall_motif={(15, 5), (7, 20), (13, 7), (14, 13), (13, 9), (7, 14)},
        trap_motif={(18, 17), (5, 14), (16, 3), (10, 19), (7, 18), (18, 8)},
        symmetry=4)

    # L37
    def dual_pendulum(a, b, t='r'):
        if a <= 0 or b <= 0: return ''
        return walk(a) + t + dual_pendulum(a-1, b-2, 'rr'+t) + walk(b) + t + dual_pendulum(a-2, b-1, t) + t + 'rr' + walk(a) + 'rr'

    add((12, 12), (dual_pendulum(3, 5, 'r') + 'r') * 4,
        WALK + FOUR + 'p(A,B,T):b(A)Tp(A-1,B-2,rrT)b(B)Tp(A-2,B-1,T)Trrb(A)rr\nq(p(3,5,r)r)',
        wall_motif={(7, 1), (5, 14), (4, 12), (12, 19), (17, 9), (6, 9), (5, 12), (17, 4)},
        trap_motif={(6, 18), (12, 7), (16, 10), (10, 8), (4, 9), (14, 13), (9, 5), (7, 14)},
        symmetry=4)

    # L38
    def hanoi_g(n, t='r'):
        if n <= 0: return ''
        return hanoi_g(n-1, 'rr'+t) + walk(n) + t + hanoi_g(n-1, t) + t + 'rr' + walk(n) + 'rr'

    add((12, 12), (hanoi_g(4, 'r') + 'r') * 4,
        WALK + FOUR + 'g(N,T):g(N-1,rrT)b(N)Tg(N-1,T)Trrb(N)rr\nq(g(4,r)r)',
        wall_motif={(8, 9), (11, 17)},
        trap_motif={(11, 7), (16, 8)},
        symmetry=4)

    # L39
    def oct_stair(n): return 'srsl' * n
    def oct_mandala(n, s):
        if n <= 0 or s <= 0: return ''
        child = (oct_mandala(n-1, s-2) + 'r') * 4 if n > 1 and s > 2 else ''
        return walk(s) + 'rr' + oct_stair(n) + 'rr' + child + 'rr' + oct_stair(n) + 'rr' + walk(s) + 'rr'

    add((12, 12), (oct_mandala(3, 4) + 'r') * 4,
        WALK + FOUR + 'd(N):srsld(N-1)\nm(N,S):b(S)rrd(N)rra(N-1,S-2)rrd(N)rrb(S)rr\na(N,S):q(m(N,S)r)\na(3,4)',
        wall_motif={(15, 20), (18, 15), (21, 10), (23, 14)},
        trap_motif={(2, 11), (9, 19), (20, 19), (21, 5)},
        symmetry=4)

    # L40
    def armillary_f(n, d, t='r'):
        if n <= 0 or d <= 0: return ''
        return walk(d) + t + armillary_f(n-1, d-2, 'rr'+t) + 'rr' + armillary_f(n-2, d-3, t) + t + 'rr' + walk(d) + 'rr'
    def armillary_a(n, d, t='r'):
        return square(d) + armillary_f(n, d, t) + 'r'

    add((12, 12), armillary_a(3, 5, 'r') * 4,
        WALK + FOUR + 'c(W):q(b(W)r)\nf(N,D,T):b(D)Tf(N-1,D-2,rrT)rrf(N-2,D-3,T)Trrb(D)rr\na(N,D,T):c(D)f(N,D,T)r\nq(a(3,5,r))',
        wall_motif={(11, 9), (10, 6), (13, 6), (16, 8), (11, 11)},
        trap_motif={(13, 8), (16, 10), (18, 7), (6, 10), (6, 16)},
        symmetry=4)

    assert len(result) == len(LESSONS) == 30
    return result
