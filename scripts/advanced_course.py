"""Independent advanced course: explicit geometric oracles, never community layouts."""

CHAPTERS = [
    ('Let walls do the counting', '让墙参与计数', '壁に歩数を任せる'),
    ('Reason about recursive state', '推理递归状态', '再帰の状態を考える'),
    ('Build patterns within patterns', '图案中的图案', '模様の中の模様'),
    ('Compose recursive systems', '组合递归系统', '再帰を組み合わせる'),
]


def lesson(title, goal, observation, strategy):
    return (title, goal, [observation, strategy])


LESSONS = [
    lesson(('Tidal locks', '潮汐船闸', '潮の水門'),
           ('Synchronize unequal lanes against walls, with a finite count and alternating turns.', '用墙对齐长短不同的通道，同时控制次数和交替转向。', '壁で長さの違う通路をそろえ、回数と交互の回転を制御しよう。'),
           ('The right banks retreat every two lanes; the left bank stays fixed.', '右岸每两行退进一次，左岸始终不变。', '右岸は二列ごとに後退し、左岸は変わりません。'),
           ('A long walk stops at each bank. Pass the turn as an instruction and reverse it for the next lane.', '足够长的前进会停在岸边。把转向作为指令参数，下一行反转它。', '長い前進は岸で止まります。回転を命令引数にして、次の列で反転させましょう。')),
    lesson(('Resonant organ', '共鸣管风琴', '共鳴するパイプ'),
           ('Reuse one out-and-back routine in six unequal walled pipes.', '让同一个往返过程适应六根长短不同的墙管。', '同じ往復手続きを、長さの違う六本の通路に使おう。'),
           ('Each pipe has a cap above and a shared stop below.', '每根管道上方有端盖，下方有共同的停止线。', '各通路には上の蓋と、下の共通の停止線があります。'),
           ('Overrun in both directions, then move four cells sideways and restore the heading.', '出发和返回都可以多走；然后横移四格，恢复朝向。', '往路も復路も長めに進み、横へ四マス移って向きを戻しましょう。')),
    lesson(('Stepped cloister', '层退回廊', '段々の回廊'),
           ('Track two dimensions while a rectangular route contracts inward.', '用两个尺寸参数跟踪逐层向内收缩的长方形路径。', '二つの寸法を追いながら、長方形の道筋を内側へ縮めよう。'),
           ('Opposite legs differ by two cells; a complete layer consumes four of each dimension.', '相对的两段相差两格；完整一层让两个尺寸各减四。', '向かい合う区間の差は二マス。一周で両寸法が四ずつ減ります。'),
           ('Separate the counted walk from a layer procedure with height and width parameters.', '把计步前进独立出来，再用高度、宽度两个参数定义一层。', '歩数指定を独立させ、高さと幅を引数に持つ一層の手続きを作りましょう。')),
    lesson(('Counterpoise', '交错悬臂', '交互の腕木'),
           ('Grow branches while alternating chirality and preserving a shared spine.', '让分支逐渐增长、左右交替，同时保持共用主干。', '枝を伸ばし、左右を交互に変えながら、共通の幹を保とう。'),
           ('Five arms grow by two cells; their roots rise four cells each time.', '五根悬臂每次增长两格，根部每次上移四格。', '五本の腕は二マスずつ伸び、根元は四マスずつ上がります。'),
           ('Use count, length and turn parameters. Return to the spine before advancing its root.', '分别传递次数、长度和转向。先回到主干，再移动根部。', '回数、長さ、回転を渡し、幹に戻ってから根元を進めましょう。')),
    lesson(('Gated pinwheel', '闸门风车', '水門の風車'),
           ('Compose a bent arm that returns home facing the next rotated arm.', '组合弯折分支，让它回到中心时朝向下一条旋转分支。', '曲がった腕を組み合わせ、中心に戻る時に次の腕の方向を向こう。'),
           ('Each arm has a long stem, a sideways gate and a short terminal passage.', '每条分支都有长主干、侧向闸门和末端短通道。', '各腕には長い幹、横の水門、短い末端通路があります。'),
           ('Name the counted walk and the complete arm separately; verify its final heading before fourfold reuse.', '分别命名计步和整条分支；重复四次之前，先检查结束朝向。', '歩数指定と腕全体を別々に名付け、四回使う前に最後の向きを確かめましょう。')),
    lesson(('Braided stair', '双线编阶', '編み込む階段'),
           ('Swap two instruction arguments while the horizontal reach shrinks.', '水平跨度逐渐缩短时，交换两个指令参数。', '横の長さを縮めながら、二つの命令引数を交換しよう。'),
           ('Each rise is three cells; horizontal legs are 10, 8, 6, 4 and 2.', '每段上升三格，横段依次长 10、8、6、4、2。', '縦は三マス、横は 10、8、6、4、2 マスです。'),
           ('Pass left and right turns separately, then exchange their parameter positions at the recursive call.', '把左右转分别传入，在递归调用时交换参数位置。', '左右の回転を別々に渡し、再帰呼び出しで引数の位置を交換しましょう。')),
    lesson(('Counterweight stair', '此消彼长', '釣り合う階段'),
           ('Change two numeric parameters in opposite directions, retrace the stair and rotate it four ways.', '让两个数值参数反向变化，原路折返阶梯后再做四向旋转。', '二つの数値引数を逆方向に変え、階段を引き返して四方向へ回転させよう。'),
           ('Vertical legs shrink from four to one; horizontal legs grow from one to four. Four stairs share the center.', '纵段从四缩到一，横段从一增到四；四条阶梯共用中心。', '縦は四から一へ縮み、横は一から四へ伸びます。四つの階段は中心を共有します。'),
           ('Recurse with X-1 and Y+1, then undo the horizontal and vertical legs after the child returns.', '以 X-1、Y+1 递归；子调用返回后，依次撤销横段和纵段。', 'X-1 と Y+1 で再帰し、子から戻ったら横と縦の区間を逆にたどりましょう。')),
    lesson(('Hinged rosette', '折页花窗', '折り重なる花窓'),
           ('Use work after a recursive call to retrace a nested arm, then rotate it.', '用递归返回后的动作折返嵌套分支，再整体旋转。', '再帰から戻った後の動きで、入れ子の腕を引き返して回転させよう。'),
           ('The hooks shrink by two cells. Every nested call must return to its own starting pose.', '弯钩逐层缩短两格；每层调用都必须回到自己的起点和朝向。', '曲がりは二マスずつ縮み、各呼び出しは元の位置と向きに戻ります。'),
           ('Walk outward, turn into a smaller hook, then undo the turn and return before rotating the whole arm.', '先向外走，转进较小弯钩；返回后撤销转向、回到中心，再旋转整条分支。', '外へ進み、小さな曲がりへ回転し、戻ったら回転を戻して中心へ引き返しましょう。')),
    lesson(('Lantern boughs', '灯树分杈', '灯りの枝分かれ'),
           ('Visit both recursive children and restore the parent’s position and heading.', '依次遍历两个递归子分支，并恢复父分支的位置和朝向。', '二つの再帰の枝を訪ね、親の位置と向きを復元しよう。'),
           ('Each junction splits left and right; lengths fall 7, 5, 3, 1.', '每个节点向左右分杈，长度依次是 7、5、3、1。', '各節で左右に分かれ、長さは 7、5、3、1 です。'),
           ('A child routine must return home. Between children use a half turn, then retrace the parent stem.', '子过程必须原路返回；两次子调用之间掉头，最后折返父主干。', '子は元へ戻る必要があります。二つの子の間で半回転し、最後に親の幹を引き返しましょう。')),
    lesson(('Contrary courts', '相向庭院', '逆向きの中庭'),
           ('Use mutually recursive procedures that exchange dimensions and turn direction.', '用相互递归的过程，交换尺寸并改变环绕方向。', '相互再帰で寸法と周回方向を交換しよう。'),
           ('Clockwise and counterclockwise rectangles share a corner, but exchange their long and short axes.', '顺、逆时针长方形共用角点，却交替交换长短轴。', '順回りと逆回りの長方形は角を共有し、長短の軸を交換します。'),
           ('Make two layer procedures call each other with the dimensions exchanged and reduced by two.', '写两个互相调用的层过程，传入交换后各减二的尺寸。', '二つの層の手続きを互いに呼び、交換して二ずつ減らした寸法を渡しましょう。')),
    lesson(('Lattice atelier', '格窗工坊', '格子窓の工房'),
           ('Nest a fourfold instruction repeater inside finite rows of reusable window tiles.', '把四次指令重复嵌入有限行数，复用整块窗格。', '四回の命令反復を有限の列に入れ、窓の単位全体を再利用しよう。'),
           ('Sixteen windows form a four-by-four arrangement, linked along each lower edge.', '十六扇窗排成四行四列，沿每行下沿连接。', '十六の窓が四行四列に並び、各行の下辺でつながります。'),
           ('Separate walking, repetition, one window and one row. A row must return left before rising.', '区分计步、重复、单窗和整行；每行结束先返回左端，再上移。', '歩数、反復、窓、行を分けましょう。行の後は左へ戻ってから上がります。')),
    lesson(('Shifting registers', '换位寄存', '入れ替わる数値'),
           ('Exchange two numeric roles while alternating the connector’s turn.', '让两个数值参数交换职责，同时交替连接处转向。', '二つの数値引数の役割を交換し、接続の回転も交互に変えよう。'),
           ('Widths are 8, 4, 6, 2; gaps are 4, 6, 2, 4. Neither sequence changes monotonically.', '横宽为 8、4、6、2，间距为 4、6、2、4；两列都不是单调变化。', '幅は 8、4、6、2、間隔は 4、6、2、4。どちらも単調には変わりません。'),
           ('After a lane of X and a gap of Y, recurse with Y and X-2, plus the opposite turn.', '走完 X 长的横段和 Y 长的间隔后，用 Y、X-2 和反向转向递归。', '幅 X と間隔 Y の後、Y、X-2 と逆の回転で再帰しましょう。')),
    lesson(('Recursive lantern', '递归灯宫', '再帰の灯宮'),
           ('Assemble four rotated subcurves by swapping two turn parameters at each level.', '每层交换两个转向参数，把四条旋转子曲线拼成整体。', '各段で二つの回転引数を交換し、四つの回転した曲線をつなごう。'),
           ('The passage has four similar quarters, each made from four smaller quarters.', '通道分成四个相似区域，每个区域又由四个更小区域组成。', '通路には似た四区画があり、それぞれも小さな四区画でできています。'),
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
    result = []

    def add(start, commands, source, geometry=None, traps=()):
        # Geometry is expressed independently of the H source. Long walks may intentionally
        # overrun its end caps, so replay those attempted steps against the generated walls.
        safe = {start, *trace(start, geometry or commands)}
        assert not (safe & set(traps))
        walls = sorted(set(outline(safe)) - set(traps))
        result.append((start, commands, source, sorted(safe - {start}), walls, list(traps)))

    widths = [18, 18, 14, 14, 10, 10]
    geometry = 'r' + ''.join(walk(width)+turn+walk(3)+turn
                             for width, turn in zip(widths, ['r', 'l']*3))
    commands = 'r' + ''.join(walk(24)+turn+walk(3)+turn for turn in ['rr'*i+'r' for i in range(6)])
    add((3, 3), commands, WALK+'a(N,T):b(24)Tb(3)Ta(N-1,rrT)\nra(6,r)', geometry)

    lengths = [5, 9, 13, 17, 13, 9]
    geometry = ''.join(walk(n)+'rr'+walk(n)+('lssssl' if i < 5 else '')
                       for i, n in enumerate(lengths))
    commands = ''.join(walk(24)+'rr'+walk(24)+('lssssl' if i < 5 else '') for i in range(6))
    add((2, 22), commands, WALK+'a(N):b(24)rrb(24)lb(4)la(N-1)\na(6)', geometry)

    commands = ''.join(walk(h)+'r'+walk(w)+'r'+walk(h-2)+'r'+walk(w-2)+'r'
                       for h, w in [(18, 14), (14, 10), (10, 6), (6, 2)])
    add((5, 21), commands, WALK+'a(H,W):b(H)rb(W)rb(H-2)rb(W-2)ra(H-4,W-4)\na(18,14)')

    commands = ''.join(turn+walk(n)+'rr'+walk(n)+turn+walk(4)
                       for n, turn in zip([2, 4, 6, 8, 10], ['rr'*i+'r' for i in range(5)]))
    add((12, 22), commands, WALK+'a(K,N,T):Tb(N)rrb(N)Tb(4)a(K-1,N+2,rrT)\na(5,2,r)')

    arm = walk(9)+'r'+walk(3)+'lssrrssr'+walk(3)+'l'+walk(9)+'r'
    add((12, 12), arm*4, WALK+'a:b(9)rb(3)lb(2)rrb(2)rb(3)lb(9)r\naaaa')

    commands = ''.join(walk(3)+turn+walk(n)+other
                       for n, turn, other in zip([10, 8, 6, 4, 2], ['r', 'l', 'r', 'l', 'r'], ['l', 'r', 'l', 'r', 'l']))
    add((5, 21), commands, WALK+'a(N,X,Y):b(3)Xb(N)Ya(N-2,Y,X)\na(10,r,l)')

    def counterweight(x, y):
        if x <= 0:
            return ''
        return walk(x)+'r'+walk(y)+'l'+counterweight(x-1, y+1)+'l'+walk(y)+'l'+walk(x)+'rr'

    add((12, 12), (counterweight(4, 1)+'r')*4, WALK+FOUR+
        'a(X,Y):b(X)rb(Y)la(X-1,Y+1)lb(Y)lb(X)rr\nq(a(4,1)r)')

    def hook(n):
        return '' if n <= 0 else walk(n)+'r'+hook(n-2)+'lrr'+walk(n)+'rr'

    add((12, 12), (hook(10)+'r')*4, WALK+'a(N):b(N)ra(N-2)lrrb(N)rr\nc:a(10)r\ncccc')

    def tree(n):
        return '' if n <= 0 else walk(n)+'l'+tree(n-2)+'rr'+tree(n-2)+'r'+walk(n)+'rr'

    add((12, 23), tree(7), WALK+'a(N):b(N)la(N-2)rra(N-2)rb(N)rr\na(7)')

    def courts(w, h, turn):
        if min(w, h) <= 0:
            return ''
        other = 'l' if turn == 'r' else 'r'
        return (walk(w)+turn+walk(h)+turn)*2+turn+courts(h-2, w-2, other)

    add((12, 12), courts(8, 10, 'r'), WALK+
        'a(W,H):b(W)rb(H)rb(W)rb(H)rrc(H-2,W-2)\n'
        'c(W,H):b(W)lb(H)lb(W)lb(H)lla(H-2,W-2)\na(8,10)')

    row = (square(2)+'rssssl')*4+'l'+walk(16)+'r'
    commands = ''.join(row+(walk(5) if i < 3 else '') for i in range(4))
    add((3, 22), commands, WALK+FOUR+
        'd(N):q(b(N)r)\ne:d(2)rb(4)l\na(N):q(e)lb(16)rb(5)a(N-1)\na(4)')

    commands = 'r'+''.join(walk(x)+turn+walk(y)+turn
                           for x, y, turn in [(8, 4, 'r'), (4, 6, 'rrr'), (6, 2, 'rrrrr'), (2, 4, 'rrrrrrr')])
    add((3, 3), commands, WALK+'a(K,X,Y,T):b(X)Tb(Y)Ta(K-1,Y,X-2,rrT)\nra(4,8,4,r)')

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
