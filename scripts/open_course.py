"""Open geometric puzzles: target motifs and authored landmarks, never route outlines."""


def lesson(title, goal, observation, strategy):
    return title, goal, [observation, strategy]


LESSONS = [
    lesson(('Tidal compass', '潮汐罗盘', '潮の羅針盤'),
           ('Combine wall-assisted stops with four returning lantern loops.', '用局部墙面停靠，组合四条能返回中心的灯环。', '局所的な壁で止まり、中心へ戻る四つの灯りの輪を組み合わせよう。'),
           ('Opposite arms have equal lengths; the little loops sit beside their end stops.', '相对的两臂等长，小灯环在端墙旁边。', '向かい合う腕は同じ長さで、小さな輪は端の壁の横にあります。'),
           ('A long outward walk can use a wall; count the return distance and preserve the next heading.', '向外可借墙停下，返回则需要计步，并留意下一臂的朝向。', '往路は壁で止め、復路の歩数と次の腕の向きを考えましょう。')),
    lesson(('Octave beacon', '八音星芒', '八音の星'),
           ('Compose straight rays and diagonal stair rays around a common center.', '围绕共同中心，组合直射线与阶梯状斜射线。', '共通の中心から、直線と階段状の斜線を組み合わせよう。'),
           ('Four long rays alternate with four shorter diagonal rays. The open gaps connect them.', '四条长直线与四条短斜线交替，射线之间保留开放空隙。', '四本の長い直線と四本の短い斜線が交互に並び、間は開いています。'),
           ('Give the diagonal step its own counter. Return each ray to the center before rotating.', '为斜向单元单独计数，每条射线先返回中心，再旋转。', '斜めの単位を別の歩数で数え、各線から中心へ戻って回転しましょう。')),
    lesson(('Prismatic kites', '棱镜风筝', 'プリズムの凧'),
           ('Build nested diamonds by reusing a diagonal step and shrinking its count.', '复用斜向阶梯单元，递减次数，构造嵌套菱形。', '斜めの階段を再利用し、回数を減らして菱形を入れ子にしよう。'),
           ('The three diamonds have diagonal sides of nine, six and three units.', '三层菱形的斜边分别由九、六、三个单元组成。', '三つの菱形の斜辺は九、六、三単位です。'),
           ('A diagonal unit preserves heading. Close four sides, then move inward to the next diamond.', '一个斜向单元保持朝向；走完四边，再向内移动到下一层。', '斜めの単位では向きが保たれます。四辺を閉じ、内側の菱形へ移りましょう。')),
    lesson(('Sandglass weave', '沙漏织影', '砂時計の織り目'),
           ('Use separate shrinking and growing recursions to weave a reflected hourglass.', '分别用收缩和增长递归，织出上下映照的沙漏。', '縮む再帰と伸びる再帰を分け、上下に映る砂時計を織ろう。'),
           ('The half-widths shrink 8, 6, 4, 2, then grow 4, 6, 8. Rows are three cells apart.', '半行宽依次为 8、6、4、2、4、6、8；行距为三格。', '半幅は 8、6、4、2、4、6、8、行の間隔は三マスです。'),
           ('Return each row to its middle. Treat the narrow waist once when joining the two phases.', '每行返回中点，连接两个阶段时只经过一次最窄腰部。', '各行は中央へ戻り、二段階をつなぐ時は最も細い部分を一度だけ扱いましょう。')),
    lesson(('Orbital lanterns', '四极灯环', '軌道の灯籠'),
           ('Compose an outward trip, a square lantern and an exact return before rotation.', '组合向外行走、方形灯环与准确折返，再整体旋转。', '往路、四角い灯り、正確な復路を組み合わせて回転させよう。'),
           ('Each lantern is offset to one side of its spoke; the spaces between spokes stay open.', '每个灯环偏在辐条的一侧，辐条之间的区域保持开放。', '各灯籠は放射線の片側に寄り、線の間は開いています。'),
           ('Make the lantern routine restore its pose. Undo the side turn before walking home.', '让灯环过程恢复自身状态，返回中心前先撤销侧向转弯。', '灯籠の手続きは元の状態へ戻し、中心へ戻る前に横の回転を戻しましょう。')),
    lesson(('Ribbon wings', '交织羽翼', '織り重なる翼'),
           ('Swap two turn arguments while shrinking a folded ribbon, then unwind it.', '交换两个转向参数，缩短折带，并在递归返回时折返。', '二つの回転引数を交換し、折り帯を縮めて再帰から戻る時に引き返そう。'),
           ('The four wings use reaches 8, 6, 4, 2 and a fixed two-cell rise.', '四片羽翼的跨度依次为 8、6、4、2，每层上升两格。', '四枚の翼の幅は 8、6、4、2、各段は二マス上がります。'),
           ('The child call swaps left and right; after it returns, reverse the two segments of its parent.', '子调用交换左右转；子调用返回后，倒序撤销父层的两段移动。', '子では左右を交換し、戻った後に親の二区間を逆順で戻りましょう。')),
    lesson(('Argyle constellation', '菱窗星群', '菱形の星座'),
           ('Separate a diagonal walker, one diamond, one row and the complete constellation.', '分离斜向前进、单个菱窗、整行与完整星群的过程。', '斜めの歩行、菱形一つ、一行、星座全体を分けよう。'),
           ('Nine hollow diamonds form a square constellation. Their interiors and the gaps are usable space.', '九个空心菱窗组成方阵，内部和窗间空隙都可利用。', '九つの空いた菱形が正方形に並び、内部と隙間も使えます。'),
           ('Make one diamond close at its starting pose, then organize the translations separately.', '让单个菱窗闭合并恢复起始状态，再独立组织平移。', '菱形を元の状態で閉じ、平行移動は別に組み立てましょう。')),
    lesson(('Folding shells', '折叠海螺', '折り重なる貝殻'),
           ('Use recursive unwinding to return from four nested folds and rotate the shell.', '通过递归返回折返四层弯折，再旋转整枚海螺。', '再帰から戻って四つの折れ曲がりを引き返し、貝殻を回転させよう。'),
           ('Fold lengths are 11, 8, 5 and 2. Open pockets let you choose how to move between nearby lights.', '弯折长度为 11、8、5、2，开放的口袋允许在相邻灯点之间选择走法。', '折り目の長さは 11、8、5、2。開いた空間では近い灯りの間の進み方を選べます。'),
           ('After visiting the smaller fold, undo its turn and retrace the parent before rotating.', '走完较小弯折后，撤销转向并折返父层，然后才整体旋转。', '小さい折り目の後、回転を戻して親を引き返し、それから全体を回しましょう。')),
    lesson(('Twin coral', '双生珊瑚', '双子の珊瑚'),
           ('Visit both recursive branches, restore their parent pose and reflect the whole tree.', '访问两个递归分支，恢复父状态，再映照整棵树。', '再帰の二つの枝を訪ね、親の状態に戻って木全体を反転させよう。'),
           ('Two branching crowns share a center; each has lengths 8, 6, 4 and 2.', '两顶分杈树冠共用中心，各层长度是 8、6、4、2。', '二つの枝分かれした冠は中心を共有し、長さは 8、6、4、2 です。'),
           ('Give each child the same return contract. Rotate only after the complete tree returns.', '让两个子分支遵守相同的折返约定，整树返回后再旋转。', '二つの子が同じ戻り方を守り、木全体が戻ってから回転しましょう。')),
    lesson(('Counterturn medallion', '相向回纹', '逆回りの紋章'),
           ('Exchange rectangle dimensions and turn direction through mutual recursion.', '通过相互递归交换长方形尺寸与环绕方向。', '相互再帰で長方形の寸法と周回方向を交換しよう。'),
           ('Four sectors overlap at the center. Within a sector, successive loops turn in opposite directions.', '四个扇区在中心相接，每个扇区中的相邻回环方向相反。', '四区画は中心で重なり、区画内の隣り合う輪は逆向きに回ります。'),
           ('Use two procedures with exchanged, reduced dimensions; verify the sector’s heading before reuse.', '用两个过程传递交换并缩小的尺寸，复用前检查扇区的结束朝向。', '二つの手続きで寸法を交換して縮め、再利用の前に区画の最後の向きを確かめましょう。')),
    lesson(('Lantern halo', '悬灯星阁', '灯籠の光輪'),
           ('Nest a centered window routine inside a two-window sector and a fourfold repeater.', '把居中窗框嵌入双窗扇区，再交给四次重复器。', '中央に戻る窓を二窓の区画に入れ、四回の反復へ渡そう。'),
           ('Eight square windows surround a spacious central court; cardinal and corner windows alternate.', '八扇方窗围绕中央留白，轴向窗与角窗交替。', '八つの四角い窓が広い中央の庭を囲み、軸上と角の窓が交互に並びます。'),
           ('Separate the window’s return contract from the sector’s translation and quarter-turn contract.', '区分窗框的原地折返约定，以及扇区的平移和四分之一圈转向约定。', '窓が元へ戻る条件と、区画の移動と四分の一回転の条件を分けましょう。')),
    lesson(('Woven vortices', '交错涡流', '織りなす渦'),
           ('Exchange two numeric roles and a turn argument while unfolding four returning vortices.', '交换两个数值参数与转向参数，展开四条能返回中心的涡流。', '二つの数値の役割と回転引数を交換し、中心に戻る四つの渦を展開しよう。'),
           ('Horizontal reaches alternate 8, 4, 6, 2; the other dimension advances one cell per two count units.', '横向跨度依次为 8、4、6、2；另一维每两个计数单位前进一步。', '横の幅は 8、4、6、2 と変わり、もう一方は二つの数につき一マス進みます。'),
           ('Keep the two counters distinct. After the child returns, undo the parent using its original arguments.', '保留两个计步器的区别，子调用返回后，用父层原参数倒序折返。', '二つの数え方を分け、子から戻った後は親の元の引数で逆に戻りましょう。')),
]

WALK = 'b(N):sb(N-1)\n'
FOUR = 'q(P):PPPP\n'


def walk(n):
    return 's' * max(n, 0)


def square(n):
    return (walk(n) + 'r') * 4


def rotate(point, turns=1):
    x, y = point
    for _ in range(turns % 4):
        x, y = 24-y, x
    return x, y


def orbit(points, symmetry=4):
    return {rotate(p, turn) for p in points for turn in range(0, 4, 4//symmetry)}


def landmarks(safe, wall_motif, trap_motif, symmetry=4):
    """Place authored islands and warning marks in the motif's negative space.

    Protect the intended routes in all permitted starting rotations, rather than
    boxing in a single route. Motifs are explicitly authored per board below.
    """
    protected = orbit(safe, symmetry) if symmetry > 1 else set(safe)
    walls = orbit(wall_motif, symmetry) - protected
    traps = orbit(trap_motif, symmetry) - protected - walls
    assert walls and traps
    return sorted(walls), sorted(traps)


def garden_obstacles(safe):
    return landmarks(safe, [(5, 5), (6, 5), (7, 5), (5, 6), (5, 7)],
                     [(9, 9), (11, 11), (13, 11)])


# Local stops, small islands and trap accents. None is a path-border stencil.
MOTIFS = [
    ([(11, 5), (12, 5), (13, 5), (22, 11), (22, 12), (22, 13)],
     [(4, 11), (13, 7), (11, 11), (7, 7), (8, 8)], 2),
    ([(11, 3), (12, 3), (13, 3), (7, 7), (7, 8)],
     [(11, 9), (10, 8), (9, 5)], 4),
    ([(11, 8), (12, 8), (13, 8), (6, 6), (7, 6)],
     [(10, 6), (9, 10), (11, 11)], 4),
    ([(2, 3), (3, 3), (2, 4), (22, 3), (21, 3), (22, 4), (8, 8), (16, 8)],
     [(x, y) for x, y in [(4, 5), (5, 6), (6, 7), (7, 8), (9, 10), (10, 11)]
      for x in (x, 24-x)], 2),
    ([(14, 5), (15, 5), (15, 6), (8, 9), (9, 9)],
     [(5, 9), (7, 11), (11, 11)], 4),
    ([(6, 6), (7, 6), (6, 7), (10, 9), (10, 10)],
     [(13, 2), (14, 3), (15, 4), (17, 10)], 4),
    ([(8, 8), (9, 8), (8, 9), (11, 11)],
     [(3, 5), (3, 6), (3, 7), (9, 12)], 4),
    ([(5, 5), (6, 5), (5, 6), (9, 9)],
     [(11, 2), (12, 2), (13, 2), (10, 8)], 4),
    ([(8, 3), (9, 3), (10, 3), (5, 5), (5, 6), (5, 7)],
     [(5, 4), (6, 3), (7, 2), (17, 2), (18, 3), (19, 4)], 2),
    ([(4, 4), (5, 4), (4, 5), (10, 10)],
     [(7, 5), (9, 7), (11, 9)], 4),
    ([(9, 9), (10, 9), (9, 10), (2, 2), (3, 2), (2, 3)],
     [(12, 1), (11, 2), (13, 2), (16, 8)], 4),
    ([(5, 5), (6, 5), (5, 6), (10, 10)],
     [(12, 1), (14, 3), (16, 5), (18, 7)], 4),
]


def designs(trace):
    result = []

    def add(commands, source, targets=None, geometry=None):
        index = len(result)
        safe = {(12, 12), *trace((12, 12), geometry or commands)}
        walls, traps = landmarks(safe, *MOTIFS[index])
        result.append(((12, 12), commands, source,
                       sorted((safe if targets is None else set(targets)) - {(12, 12)}), walls, traps))

    # 11: stops only at the tips; every returning lantern is otherwise open.
    lengths = [6, 9, 6, 9]
    geometry = ''.join(walk(n)+'r'+square(2)+'r'+walk(n)+'rrr' for n in lengths)
    commands = ''.join(walk(24)+'r'+square(2)+'r'+walk(n)+'rrr' for n in lengths)
    # Trace overrun attempts against the local caps, not against a corridor border.
    safe = {(12, 12), *trace((12, 12), geometry)}
    walls, traps = landmarks(safe, *MOTIFS[0])
    result.append(((12, 12), commands, WALK+FOUR+
                   'a(N):b(24)rq(b(2)r)rb(N)rrr\na(6)a(9)a(6)a(9)', sorted(safe-{(12, 12)}), walls, traps))

    diagonal = lambda n: 'srsl' * n
    geometry = (walk(8)+'rr'+walk(8)+'rr'+diagonal(4)+'rr'+diagonal(4)+'rrr')*4
    commands = (walk(24)+'rr'+walk(8)+'rr'+diagonal(4)+'rr'+diagonal(4)+'rrr')*4
    safe = {(12, 12), *trace((12, 12), geometry)}
    walls, traps = landmarks(safe, *MOTIFS[1])
    result.append(((12, 12), commands, WALK+
                   'd(N):srsld(N-1)\na:b(24)rrb(8)rrd(4)rrd(4)rrr\naaaa', sorted(safe-{(12, 12)}), walls, traps))

    commands = 'l'+walk(9)+'r'+''.join((diagonal(n)+'r')*4+'r'+walk(3)+'l' for n in (9, 6, 3))
    targets = {p for n in (9, 6, 3) for p in trace((12-n, 12), (diagonal(n)+'r')*4)}
    add(commands, WALK+FOUR+'d(N):srsld(N-1)\na(N):q(d(N)r)rb(3)la(N-3)\nlb(9)ra(9)', targets=targets)

    row = lambda n: 'l'+walk(n)+'rr'+walk(2*n)+'rr'+walk(n)+'r'
    geometry = 'rr'+walk(9)+'rr'+('sss'.join(row(n) for n in (8, 6, 4, 2, 4, 6, 8)))
    targets = {(x, y) for y, n in zip(range(21, 2, -3), (8, 6, 4, 2, 4, 6, 8))
               for x in range(12-n, 13+n, 2)}
    add(geometry+'sss', WALK+
        'd(N):lb(N)rrb(N+N)rrb(N)r\na(N):d(N)b(3)a(N-2)\n'
        'c(K,N):d(N)b(3)c(K-1,N+2)\nrrb(9)rra(8)c(3,4)', targets=targets, geometry=geometry)

    arm = walk(8)+'r'+square(4)+'lrr'+walk(8)+'rrr'
    add(arm*4, WALK+FOUR+'a:b(8)rq(b(4)r)lrrb(8)rrr\naaaa')

    def ribbon(n, t='r', u='l'):
        if n <= 0:
            return ''
        return walk(2)+t+walk(n)+u+ribbon(n-2, u, t)+'rr'+t+walk(n)+u+walk(2)+'rr'

    add((ribbon(8)+'r')*4, WALK+FOUR+
        'a(N,T,U):b(2)Tb(N)Ua(N-2,U,T)rrTb(N)Ub(2)rr\nq(a(8,r,l)r)')

    diamond = (diagonal(2)+'r')*4
    row_commands = (diamond+'r'+walk(6)+'l')*3+'l'+walk(18)+'r'
    commands = 'l'+walk(8)+'l'+walk(6)+'rr'+(row_commands+walk(6))*3
    targets = set()
    for x in (4, 10, 16):
        for y in (6, 12, 18):
            targets.update(trace((x, y), diamond))
    add(commands, WALK+FOUR+'d(N):srsld(N-1)\nw:q(d(2)r)\ne:wrb(6)l\n'
        'a(N):eeelb(18)rb(6)a(N-1)\nlb(8)lb(6)rra(3)', targets=targets)

    def hook(n):
        return '' if n <= 0 else walk(n)+'r'+hook(n-3)+'lrr'+walk(n)+'rr'

    add((hook(11)+'r')*4, WALK+FOUR+'a(N):b(N)ra(N-3)lrrb(N)rr\nq(a(11)r)')

    def tree(n):
        return '' if n <= 0 else walk(n)+'l'+tree(n-2)+'rr'+tree(n-2)+'r'+walk(n)+'rr'

    add((tree(8)+'rr')*2, WALK+'a(N):b(N)la(N-2)rra(N-2)rb(N)rr\nc:a(8)rr\ncc')

    def courts(w, h, turn):
        if min(w, h) <= 0:
            return ''
        other = 'l' if turn == 'r' else 'r'
        return (walk(w)+turn+walk(h)+turn)*2+turn+courts(h-2, w-2, other)

    # The complete recursive sector's net rotation is computed independently.
    sector = courts(6, 8, 'r')
    add(sector*4, WALK+FOUR+
        'a(W,H):b(W)rb(H)rb(W)rb(H)rrc(H-2,W-2)\n'
        'c(W,H):b(W)lb(H)lb(W)lb(H)lla(H-2,W-2)\nq(a(6,8))')

    window = 'lsslssrr'+square(4)+'ssrssl'
    sector = walk(7)+window+'r'+walk(7)+window+'r'+walk(7)+'r'+walk(7)+'rr'
    targets = set()
    for center in orbit([(12, 5), (19, 5)]):
        targets.update(trace((center[0]-2, center[1]+2), square(4)))
    add(sector*4, WALK+FOUR+'w:lb(2)lb(2)rrq(b(4)r)b(2)rb(2)l\n'
        'a:b(7)wrb(7)wrb(7)rb(7)rr\naaaa', targets=targets)

    def vortex(k, x, y, t='r'):
        if min(k, x, y) <= 0:
            return ''
        return (walk(x)+t+walk((y+1)//2)+t+vortex(k-1, y, x-2, 'rr'+t)
                +t+walk((y+1)//2)+'rr'+t+walk(x)+'rr')

    add((vortex(4, 8, 4)+'r')*4, WALK+FOUR+
        'c(N):sc(N-2)\na(K,X,Y,T):b(X)Tc(Y)Ta(K-1,Y,X-2,rrT)Tc(Y)rrTb(X)rr\nq(a(4,8,4,r)r)')
    return result


LATE_MOTIFS = [
    ([(8, 8), (9, 8), (8, 9), (16, 16)], [(6, 6), (8, 10), (10, 10)]),
    ([(8, 8), (9, 8), (8, 9), (11, 11)], [(3, 18), (6, 3)]),
    ([(6, 6), (7, 6), (8, 6), (11, 11)], [(4, 4), (10, 4)]),
    ([(3, 4), (4, 4), (5, 4), (10, 9), (10, 10), (12, 12)],
     [(8, 6), (8, 8), (12, 10), (8, 12)]),
    ([(8, 6), (9, 6), (7, 7), (7, 8)], [(11, 8), (8, 9)]),
    ([(9, 4), (10, 4), (11, 4), (6, 4), (6, 5)], [(6, 3), (6, 6), (11, 11)]),
    ([(10, 2), (11, 2), (10, 3), (11, 3), (8, 6), (8, 7), (8, 8)],
     [(6, 8), (6, 11), (11, 11)]),
    ([(9, 3), (10, 3), (11, 3), (11, 4), (11, 5)], [(9, 5), (7, 7), (9, 9)]),
]


def late_obstacles(safe, index, existing_traps=()):
    walls, traps = landmarks(safe, *LATE_MOTIFS[index], symmetry=1 if index == 3 else 4)
    traps = sorted(set(traps) | set(existing_traps))
    assert not (set(traps) & safe)
    return walls, traps
