"""Ten synthesis lessons (L41–L50), with independent geometric command oracles."""
from advanced_course import WALK, FOUR, walk, square
from master_course import LESSONS as MASTER_LESSONS, master_designs, lesson
from open_course import landmarks, stroke

CHAPTERS = [
    ('Transformations and inverse paths', '变换与逆程', '変換と逆の道筋'),
    ('Layered recursive synthesis', '多层递归综合', '多層再帰の総合'),
]

LESSONS = MASTER_LESSONS + [
    lesson(('Alternating mirror halls', '交替镜廊', '交互の鏡回廊'),
           ('Swap shrinking rectangle dimensions and chirality while restoring every entrance pose.',
            '交换递减的矩形双尺寸与旋向，每层结束都恢复入口位置和朝向。',
            '縮む長方形の二寸法と回転方向を交換し、各段で入口の位置と向きへ戻ろう。'),
           ('Each quadrant contains three offset rectangles. Their long side changes direction at the next level.',
            '每个象限有三层错位矩形；进入下一层时，长边的方向发生交换。',
            '各区画にはずれた三段の長方形があり、次の段で長辺の方向が入れ替わります。'),
           ('Separate the closed rectangle from its two-part connector. Swap width, height and turns only in the child, then undo the connector.',
            '分离闭合矩形与两段连接线；只在子调用中交换宽、高和左右转，返回时撤销连接位移。',
            '閉じる長方形と二つの接続区間を分け、子で幅・高さ・左右を交換し、接続を戻りましょう。')),
    lesson(('Paired folding ribbons', '双序折带', '対になる折り帯'),
           ('Grow a forward instruction and its inverse together, then execute one selected expansion.',
            '同步增长正向与逆向指令，只执行选定层的展开，并在端点绕过灯框。',
            '順方向と逆方向の命令を同時に育て、選んだ段だけ実行して先端の窓を巡ろう。'),
           ('Four folded arms end in square loops. The return must undo the folds in reverse order.',
            '四条折带在末端连接方形灯框；返程必须倒序撤销弯折。',
            '四本の折り帯の先端には四角い窓があり、戻りは折れ目の逆順です。'),
           ('Carry two instruction parameters. If the next forward path is X-right-Y, its inverse is X-left-Y; use a separate numeric guard to execute the final pair.',
            '携带两个指令参数；若新正程为 X、右、Y，新逆程就是 X、左、Y。另设数值守卫，只执行最后一对。',
            '二つの命令引数を渡し、新しい順路が X・右・Y なら逆路は X・左・Y。別の数値条件で最後の対だけ実行しましょう。')),
    lesson(('Counterchanging windows', '错层窗阵', '寸法が交差する窓'),
           ('Coordinate shrinking widths, growing heights and row offsets with separate return invariants.',
            '协调逐窗变窄、逐窗增高与逐行错层，分别保持行和层的折返约定。',
            '窓ごとに狭く高くし、行のずれも制御して、行と段の復帰条件を守ろう。'),
           ('Each row has three windows. Moving right reduces width and increases height; the next row starts narrower and taller.',
            '每行三扇窗；向右一窗，宽减一、高加一，上一行的起始窗也更窄更高。',
            '各行は三窓。右へ進むと幅が一減り高さが一増え、上の行の最初の窓も狭く高くなります。'),
           ('Make a rectangle return to its corner, a row return along its changing spacings, and the outer recursion restore each seven-cell rise.',
            '让单窗回到角点，整行按变化的间距逐段折返，再由外层递归撤销每次七格上移。',
            '窓を角へ戻し、行を変わる間隔に沿って戻し、外側の再帰で七マスの上昇を戻しましょう。')),
    lesson(('Counterpoised organ', '折返风琴', '折り返すオルガン'),
           ('Alternate branch sides as reach shrinks and the terminal window grows, then unwind the central spine.',
            '沿主轴交替伸出左右分支，让臂长递减、末端灯框递增，再逐层折返。',
            '軸に沿って左右交互に枝を伸ばし、腕を短く窓を大きくして、段ごとに戻ろう。'),
           ('Along an arm, side reaches are five, four and three cells while window sides are one, two and three.',
            '同一主臂上，侧枝长为五、四、三格，灯框边长却为一、二、三格。',
            '一つの主軸で側枝は五・四・三マス、窓の辺は一・二・三マスになります。'),
           ('Keep depth, reach and window size independent. Finish each side trip before advancing the spine; invert the turn only for the child.',
            '独立传递层数、臂长和窗宽；完成侧向往返后再沿主轴前进，仅对子层反转旋向。',
            '深さ・腕の長さ・窓幅を別に渡し、横の往復後に軸を進み、子の回転だけ反転しましょう。')),
    lesson(('Lantern curve workshop', '曲线灯坊', '曲線の灯り工房'),
           ('Replace each recursive curve link with a reusable window-and-walk instruction without changing its pose contract.',
            '把递归曲线的连接步替换为可复用的灯框与前进动作，保持子曲线的状态约定。',
            '再帰曲線の接続歩行を窓と前進の命令に置き換え、部分曲線の状態条件を守ろう。'),
           ('Small square windows follow a larger folded curve. The connector has the same net displacement as a three-cell walk.',
            '小方窗沿大折线排列；每个灯框连接单元的净位移等于前进三格。',
            '小さな四角い窓が大きな折り線に沿い、各接続単位の変位は三マス前進と同じです。'),
           ('Pass the window-and-walk as an instruction argument to the curve. Its closed window must restore heading before the three-cell link.',
            '把灯框与前进组合成指令参数传入曲线；闭合灯框先恢复朝向，再执行三格连接。',
            '窓と前進を命令引数として曲線へ渡し、窓で向きを戻してから三マスを進みましょう。')),
    lesson(('Diagonal homecoming', '斜枝归航', '斜めの枝の帰路'),
           ('Build inverse stair walkers and reuse them through unequal, mirrored recursive branches.',
            '构造阶梯步进的逆过程，在深度不同、旋向交换的递归分枝中复用。',
            '階段歩行の逆手続きを作り、深さと回転が異なる再帰の枝で再利用しよう。'),
           ('Branches move diagonally with stair steps. Repeating the forward stair after a half turn does not retrace it.',
            '分枝由阶梯形成斜向位移；掉头后重复同一阶梯，并不会沿原来的格点返回。',
            '枝は階段で斜めに進み、半回転して同じ階段を繰り返しても元のマスを戻れません。'),
           ('Reverse the stair unit and exchange its turns. Give each subtree a returning pose contract before combining depths N-1 and N-2.',
            '把阶梯单元倒序并交换左右转；先保证每个子树能恢复状态，再组合 N-1 与 N-2 两种深度。',
            '階段単位を逆順にして左右を交換し、各部分木の復帰を確認して N-1 と N-2 の深さを組み合わせましょう。')),
    lesson(('Branching courtyards', '分形连庭', '枝分かれする中庭'),
           ('Place unequal recursive courtyards at alternating corners, with swapped dimensions and chirality.',
            '在交替角点放置尺寸变化规则不同的递归庭院，并交换双尺寸与旋向。',
            '交互の角に異なる縮小規則の再帰の庭を置き、二寸法と回転方向を交換しよう。'),
           ('A large rectangular circuit holds a child at each corner. Adjacent children shrink different dimensions.',
            '大矩形每个角都连接子庭院；相邻两个子庭院对宽和高采用不同的缩减规则。',
            '大きな長方形の各角に子の庭があり、隣同士で幅と高さの減らし方が異なります。'),
           ('Factor a two-corner half circuit and repeat it twice. Each child must close at its own corner before the parent continues.',
            '提取经过两角的半圈并重复两次；子庭院必须在自身角点闭合，父层才能继续。',
            '二つの角を巡る半周を二回使い、子の庭をその角で閉じてから親を進めましょう。')),
    lesson(('Layered lantern vault', '渐变灯穹', '段々に変わる灯りの天井'),
           ('Nest returning windows inside shrinking rows while window size grows between tiers.',
            '将可折返的嵌套方窗放入逐渐缩短的行，层数减少时让起始窗尺寸增大。',
            '戻れる入れ子の窓を短くなる行へ組み込み、段が減るほど最初の窓を大きくしよう。'),
           ('The tiers have three, two and one windows. Within a row they shrink; between rows the first window grows.',
            '三层分别有三、二、一扇窗；同一行内方窗缩小，上移一层时起始窗变大。',
            '三段の窓数は三・二・一。行の中では窓が縮み、上の段の最初の窓は大きくなります。'),
           ('Give inner nesting, sideways translation and upward translation separate recursions; all three must undo their displacement.',
            '分别递归处理窗内嵌套、横向平移与向上换层；三个过程都必须撤销自身位移。',
            '窓の入れ子、横の移動、上の段への移動を別々に再帰させ、三つとも変位を戻しましょう。')),
    lesson(('Returning star atlas', '星图归程', '星図からの帰還'),
           ('Dock with four decorated recursive curves and construct the inverse of both the curve and its link motif.',
            '连接四片带灯框的递归星图，同时构造子曲线和连接单元的逆程。',
            '窓で飾る四つの再帰星図へ接続し、曲線と接続単位の両方の逆路を作ろう。'),
           ('Each quadrant has a folded panel. A square at the far end must be visited before retracing to the shared center.',
            '每个象限都有一片折线窗阵；到达远端灯框后，必须返回共同中心才能旋转。',
            '各区画に折り線の窓があり、奥の窓を巡って共通の中心へ戻ってから回転します。'),
           ('Invert a decorated link by walking first and drawing the mirrored square afterward. Use reversed turn arguments for the return curve.',
            '装饰连接单元的逆过程要先前进、再画反向方框；返回曲线同时交换两个转向参数。',
            '飾る接続単位の逆路は先に歩き、次に逆向きの窓を描き、帰りの曲線では二つの回転引数も交換しましょう。')),
    lesson(('Palace of woven paths', '万象织宫', '道を織る宮殿'),
           ('Combine inverse diagonal trunks, unequal subtrees and exchanged node motifs into one returning recursive system.',
            '综合斜向主干与逆程、不同深度的子树，以及交替交换的节点图案，构造能复原状态的递归系统。',
            '斜めの幹と逆路、深さの違う部分木、交換する節の模様を統合し、元に戻る再帰系を作ろう。'),
           ('Square and diamond nodes share diagonal branches. One child exchanges the two motifs and the turns; its sibling retains them.',
            '方形与菱形节点共用斜枝；一侧子树同时交换节点图案和左右转，另一侧保持原有顺序。',
            '四角と菱形の節が斜めの枝を共有し、一方の子では模様と左右を交換し、もう一方は保ちます。'),
           ('Make both node instructions close at their entry pose. Pass them alongside depth, stride and turns, and retrace each stair trunk after both children.',
            '先让两种节点指令都在入口处闭合，再连同深度、步长和转向传递；两支结束后逆向撤销阶梯主干。',
            '二つの節の命令を入口で閉じ、深さ・歩数・回転と共に渡し、両方の子の後で階段の幹を逆に戻りましょう。')),
]


def inverse(commands):
    return ''.join({'s': 's', 'r': 'l', 'l': 'r'}[c] for c in commands[::-1])


def rectangle(w, h, turn='r'):
    return (walk(w)+turn+walk(h)+turn)*2


def mirror_halls(n, w, h, t='r', u='l'):
    if min(n, w, h) <= 0:
        return ''
    return (rectangle(w, h, t)+'ss'+t+'ss'+u+mirror_halls(n-1, h-2, w-2, u, t)
            +u+'ss'+u+'ssrr')


def folding_pair(n):
    forward = backward = 's'
    for _ in range(n):
        forward, backward = forward+'r'+backward, forward+'l'+backward
    return forward, backward


def gradient_row(n, w, h):
    if n <= 0:
        return ''
    return (rectangle(h, w)+'r'+walk(w+2)+'l'+gradient_row(n-1, w-1, h+1)
            +'l'+walk(w+2)+'r')


def gradient_tier(n, w, h):
    if n <= 0:
        return ''
    return gradient_row(3, w, h)+walk(7)+gradient_tier(n-1, w-1, h+1)+'rr'+walk(7)+'rr'


def organ(n, d, w, t='r'):
    if n <= 0:
        return ''
    return (t+walk(d)+square(w, t)+'rr'+walk(d)+t+'sss'
            +organ(n-1, d-1, w+1, 'rr'+t)+'rrsssrr')


def hilbert(n, x='r', y='l', link='ss'):
    if n <= 0:
        return ''
    return (x+hilbert(n-1, y, x, link)+link+y+hilbert(n-1, x, y, link)+link
            +hilbert(n-1, x, y, link)+y+link+hilbert(n-1, y, x, link)+x)


def stair(n, t='r', u='l'):
    return ('s'+t+'s'+u)*max(n, 0)


def stair_tree(n, d, t='r', u='l'):
    if min(n, d) <= 0:
        return ''
    stem = stair(d, t, u)
    return (stem+t+stair_tree(n-1, d-1, u, t)+'rr'+stair_tree(n-2, d-1, t, u)
            +t+'rr'+inverse(stem)+'rr')


def corner_tree(n, w, h, t='r', u='l'):
    if min(n, w, h) <= 0:
        return ''
    half = (walk(w)+t+corner_tree(n-1, h-1, w-2, u, t)
            +walk(h)+t+corner_tree(n-1, w-1, h-2, u, t))
    return half*2


def nested_window(n, w):
    if min(n, w) <= 0:
        return ''
    return square(w)+'srsl'+nested_window(n-1, w-2)+'rrrslsrr'


def window_row(n, w):
    if n <= 0:
        return ''
    return nested_window(2, w)+'r'+walk(w+2)+'l'+window_row(n-1, w-1)+'l'+walk(w+2)+'r'


def window_tier(n, w):
    if n <= 0:
        return ''
    return window_row(n, w)+walk(w+2)+window_tier(n-1, w+1)+'rr'+walk(w+2)+'rr'


def atlas_panel():
    outward = hilbert(2, 'l', 'r', square(1)+'sss')+square(1)
    return 'ssr'+outward+'rr'+inverse(outward)+'lssrrr'


def palace(n, d, t='r', u='l', p=square(1), q='srslr'*4):
    if min(n, d) <= 0:
        return ''
    stem = stair(d, t, u)
    return (p+stem+t+palace(n-1, d-1, u, t, q, p)+'rr'+palace(n-2, d-2, t, u, p, q)
            +t+'rr'+inverse(stem)+'rr')


HILBERT = 'a(N,T,U,P):Ta(N-1,U,T,P)PUa(N-1,T,U,P)Pa(N-1,T,U,P)UPa(N-1,U,T,P)T\n'
STAIRS = 'd(N,T,U):sTsUd(N-1,T,U)\ne(N,T,U):TsUse(N-1,T,U)\n'


def expert_designs(trace):
    result = master_designs(trace)

    def add(start, commands, source, wall_motif, trap_motif, symmetry=4):
        route = {start, *trace(start, commands)}
        walls, traps = landmarks(route, wall_motif, trap_motif, symmetry)
        result.append((start, commands, source, sorted(route-{start}), walls, traps))

    add((12, 12), (mirror_halls(3, 8, 6)+'r')*4, WALK+FOUR+
        'c(W,H,T):b(W)Tb(H)Tb(W)Tb(H)T\n'
        'a(N,W,H,T,U):c(W,H,T)b(2)Tb(2)Ua(N-1,H-2,W-2,U,T)Ub(2)Ub(2)rr\n'
        'q(a(3,8,6,r,l)r)',
        stroke((3, 6), (3, 10)) | stroke((7, 7), (7, 9)),
        stroke((5, 11), (9, 11)) | stroke((15, 3), (19, 3)) | {(11, 5), (11, 7)})

    forward, backward = folding_pair(5)
    add((12, 12), (forward+square(2)+'rr'+backward+'rrr')*4, FOUR+
        'a(N,X,Y):a(N-1,XrY,XlY)c(2-N,X,Y)\n'
        'c(N,X,Y):q(Xq(ssr)rrYrrr)\na(6,s,s)',
        {(11, 6), (13, 5), (13, 6)},
        {(9, 6), (10, 6), (12, 5)})

    add((3, 22), gradient_tier(3, 5, 2), WALK+
        'c(W,H):b(H)rb(W)rb(H)rb(W)r\n'
        'd(N,W,H):c(W,H)rb(W+2)ld(N-1,W-1,H+1)lb(W+2)r\n'
        'a(N,W,H):d(3,W,H)b(7)a(N-1,W-1,H+1)rrb(7)rr\na(3,5,2)',
        stroke((2, 2), (2, 22)) | stroke((4, 9), (20, 9)) | stroke((4, 16), (20, 16)),
        stroke((7, 2), (7, 21)) | stroke((13, 2), (13, 21)) | stroke((20, 2), (20, 21)), 1)

    add((12, 12), (organ(3, 5, 1)+'r')*4, WALK+FOUR+
        'c(W,T):q(b(W)T)\n'
        'a(N,D,W,T):Tb(D)c(W,T)rrb(D)Tb(3)a(N-1,D-1,W+1,rrT)rrb(3)rr\n'
        'q(a(3,5,1,r)r)',
        stroke((5, 6), (5, 10)) | stroke((10, 7), (10, 9)),
        stroke((7, 5), (10, 5)) | stroke((11, 6), (11, 8)))

    add((1, 23), hilbert(3, link=square(1)+'sss')+square(1), FOUR+HILBERT+
        'd:q(sr)sss\na(3,r,l,d)q(sr)',
        {p for x in (3, 9, 15, 21) for p in stroke((x, 2), (x, 22))} | stroke((0, 4), (0, 9)),
        {p for x in (6, 12, 18) for p in stroke((x, 2), (x, 22))}, 1)

    add((12, 12), (stair_tree(4, 4)+'r')*4, FOUR+STAIRS+
        'a(N,D,T,U):d(D,T,U)Ta(N-1,D-1,U,T)rra(N-2,D-1,T,U)Trre(D,T,U)rr\n'
        'q(a(4,4,r,l)r)',
        stroke((5, 7), (8, 7), (8, 8)) | stroke((9, 11), (10, 11)) | stroke((3, 5), (3, 7)),
        stroke((6, 10), (8, 10)) | stroke((11, 6), (11, 9)) | stroke((5, 3), (7, 3)))

    add((9, 17), corner_tree(3, 6, 5), WALK+
        'c(N,W,H,T,U):b(W)Ta(N-1,H-1,W-2,U,T)b(H)Ta(N-1,W-1,H-2,U,T)\n'
        'a(N,W,H,T,U):c(N,W,H,T,U)c(N,W,H,T,U)\na(3,6,5,r,l)',
        stroke((4, 8), (4, 23)) | stroke((5, 4), (18, 4)),
        stroke((14, 8), (14, 22)) | stroke((6, 24), (18, 24)) | stroke((12, 20), (15, 20)), 1)

    add((4, 21), window_tier(3, 3), WALK+FOUR+
        'c(N,W):q(b(W)r)srslc(N-1,W-2)rrrslsrr\n'
        'd(N,W):c(2,W)rb(W+2)ld(N-1,W-1)lb(W+2)r\n'
        'a(N,W):d(N,W)b(W+2)a(N-1,W+1)rrb(W+2)rr\na(3,3)',
        stroke((3, 5), (3, 21)) | stroke((5, 11), (11, 11)),
        stroke((10, 5), (10, 9)) | stroke((5, 17), (16, 17)) | stroke((17, 19), (17, 21)), 1)

    add((12, 12), atlas_panel()*4, WALK+FOUR+HILBERT+
        'd:q(sr)sss\ne:sssq(ls)\n'
        'c:b(2)ra(2,l,r,d)q(sr)rrq(ls)a(2,r,l,e)lb(2)rrr\ncccc',
        stroke((2, 4), (2, 10)) | stroke((5, 5), (5, 10)) | stroke((8, 8), (8, 10)) | stroke((4, 11), (6, 11)),
        stroke((4, 2), (10, 2)) | stroke((7, 4), (7, 10)) | stroke((10, 5), (10, 10)) | {(8, 4)})

    add((12, 12), (palace(4, 4)+'r')*4, FOUR+STAIRS+
        'c:q(sr)\nw:q(srslr)\n'
        'a(N,D,T,U,P,Q):Pd(D,T,U)Ta(N-1,D-1,U,T,Q,P)rra(N-2,D-2,T,U,P,Q)Trre(D,T,U)rr\n'
        'q(a(4,4,r,l,c,w)r)',
        stroke((3, 7), (3, 10)) | stroke((8, 11), (10, 11)),
        stroke((9, 3), (11, 3)) | stroke((11, 6), (11, 9)))

    assert len(result) == len(LESSONS) == 40
    return result
