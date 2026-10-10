from collections import deque
import hashlib
import json
from pathlib import Path
import unittest

from advanced_course import advanced_designs, outline
from generate_original_problems import designs, trace
from render_course_review import render
from open_course import orbit

ROOT = Path(__file__).resolve().parents[1]


class OpenCourseTests(unittest.TestCase):
    def setUp(self):
        self.problems = json.loads((ROOT / 'Sources/HerbertCore/Resources/original-problems.json').read_text())

    def test_revised_boards_have_reachable_targets_and_local_route_choices(self):
        for problem in [p for p in self.problems if p['lesson']['order'] in [4, 5, 6] or p['lesson']['order'] >= 10]:
            with self.subTest(lesson=problem['lesson']['order']):
                rows = problem['rows']
                targets = {(x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c == 'o'}
                start = next((x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c == 'u')
                walls = {(x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c == 'x'}
                traps = {(x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c == '*'}
                self.assertTrue(walls and traps)
                self.assertTrue(any(abs(x-a)+abs(y-b) == 1 for x, y in traps for a, b in targets),
                                'At least one trap must constrain a real decision near a target')
                self.assertTrue(any(abs(x-a)+abs(y-b) == 1 for x, y in walls for a, b in targets),
                                'Walls should guide the motif, not just decorate a distant corner')
                # Measure the motif itself, with a one-cell margin, not unrelated board corners.
                points = targets | {start}
                x0, x1 = max(0, min(x for x, y in points)-1), min(24, max(x for x, y in points)+1)
                y0, y1 = max(0, min(y for x, y in points)-1), min(24, max(y for x, y in points)+1)
                safe = {(x, y) for y in range(y0, y1+1) for x in range(x0, x1+1)} - walls - traps

                def neighbors(point):
                    x, y = point
                    return {(x+1, y), (x-1, y), (x, y+1), (x, y-1)} & safe

                reached, queue = {start}, deque([start])
                while queue:
                    for point in neighbors(queue.popleft()) - reached:
                        reached.add(point)
                        queue.append(point)
                self.assertTrue(targets <= reached)
                choices = sum(len(neighbors(point)) >= 3 for point in targets)
                self.assertGreaterEqual(choices / len(targets), .60,
                                        'Most targets should offer more than a two-way corridor')
                edges = sum(len(neighbors(point)) for point in reached) // 2
                self.assertGreater(edges-len(reached)+1, 8, 'The motif must have multiple safe cycles')

    def test_wall_and_trap_density_each_use_15_to_30_percent_of_enclosing_border(self):
        all_designs = designs() + advanced_designs(trace)
        for order in [4, 5, 6, *range(10, 31)]:
            with self.subTest(lesson=order):
                start, commands, _, _, walls, traps = all_designs[order-1]
                route = {start, *trace(start, commands, set(walls))}
                symmetry = 2 if order in (4, 11, 14, 19) else 1 if order in (6, 26) else 4
                capacity = len(outline(orbit(route, symmetry)))
                for cells in (walls, traps):
                    self.assertGreaterEqual(len(cells) / capacity, .15)
                    self.assertLessEqual(len(cells) / capacity, .30)
                self.assertFalse(set(walls) & set(traps))
                self.assertTrue(all(0 <= x < 25 and 0 <= y < 25 for x, y in walls + traps))

    def test_l23_through_l30_preserve_their_target_geometry_and_start(self):
        expected = [
            '4873609a1259dca4e97f3f10826f455506108dfe232fadf921c0522c6c0d0104',
            '4fe0b121aa8b8ca810073f7e939be9cfc711e2cdefe652256368458d9460e48f',
            '57eba55e19466ffd0b6c6e61c2e54fbcab90199c0b462596cf22ca6f36b4223d',
            '0a173b3735ee5d6ad2fcc4645e7c3dd2089bc7fe654cf3ef7e46c2e356404162',
            '238044fb7a63eb02fd096deb06bfe4594b0692e85ab8b24f9372040e5b3208f0',
            '390eb34cc18648c17e1ac1ec522866629f1deb0a8086df8e204983141cb3c9a4',
            'ff0c2d113ef80414bb184b3e89be798bd71beadfa55d8fb05ae9cd77b9f2e3cf',
            '2bbf542e0d8924b52bfb7516982236112960153629a6b7fd72473ed832551cb6',
        ]
        for problem, digest in zip(self.problems[22:], expected):
            geometry = [(x, y, c) for y, row in enumerate(problem['rows']) for x, c in enumerate(row) if c in 'ou']
            self.assertEqual(hashlib.sha256(json.dumps(geometry).encode()).hexdigest(), digest,
                             f"L{problem['lesson']['order']}: preserve the approved geometric motif")

    def test_authored_obstacles_leave_reference_geometry_safe(self):
        designs = advanced_designs(trace)
        self.assertEqual(len(designs), 20)
        for start, commands, source, targets, walls, traps in designs:
            route = set(trace(start, commands, set(walls)))
            self.assertTrue(set(targets) <= route)
            self.assertFalse(route & set(traps))
            self.assertFalse(set(walls) & set(traps))

    def test_offline_review_contains_real_boards_without_answer_fixtures(self):
        page = render(self.problems, self.problems)
        payload = page.split('<script>const data=', 1)[1].split(';\nconst select=', 1)[0]
        data = json.loads(payload)
        self.assertEqual([item['order'] for item in data], [4, 5, 6, *range(10, 31)])
        self.assertTrue(all(item['after'].startswith('<svg ') for item in data))
        self.assertTrue(all(item['before'] == item['after'] for item in data))
        self.assertNotIn('alternateSources', page)
        self.assertNotIn('original-solutions', page)
        self.assertNotIn('https://', page)
