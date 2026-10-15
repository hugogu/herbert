"""Exercise the return contracts that make the synthesis lessons composable."""
import hashlib
import itertools
import json
from pathlib import Path
import unittest

from expert_course import (atlas_panel, corner_tree, folding_pair, gradient_tier,
                           hilbert, inverse, mirror_halls, organ, palace, square,
                           stair_tree, window_tier)
from generate_original_problems import trace

ROOT = Path(__file__).resolve().parents[1]


class ExpertCourseTests(unittest.TestCase):
    def test_previous_forty_problem_and_reference_records_are_unchanged(self):
        for name, digest in [
            ('Sources/HerbertCore/Resources/original-problems.json',
             '4df0a050cc8562fc94e9fe09b8bb7b3da7c1fa0cc53162c8bb91fd587d1c883b'),
            ('Tests/HerbertCoreTests/Fixtures/original-solutions.json',
             '8ce5af490e7f96f3bec84779e33f3e128def993bd43dbc0777f28611af4cd79b'),
        ]:
            records = json.loads((ROOT / name).read_text())
            self.assertEqual(hashlib.sha256(json.dumps(records[:40], sort_keys=True).encode()).hexdigest(), digest)

    def test_recursive_components_return_to_the_entry_pose(self):
        for commands in [mirror_halls(3, 8, 6), gradient_tier(3, 5, 2),
                         organ(3, 5, 1), stair_tree(4, 4), corner_tree(3, 6, 5),
                         window_tier(3, 3), palace(4, 4)]:
            with self.subTest(commands=commands[:30]):
                self.assertEqual(trace((0, 0), commands, bounded=False)[-1], (0, 0))
                self.assertEqual((commands.count('r')-commands.count('l')) % 4, 0)

    def test_growth_carries_the_exact_inverse_at_every_level(self):
        for level in range(7):
            forward, backward = folding_pair(level)
            self.assertEqual(backward, inverse(forward))

    def test_decorated_curve_inverse_retraces_the_same_cells(self):
        outward = hilbert(2, 'l', 'r', square(1)+'sss')+square(1)
        forward = trace((0, 0), outward, bounded=False)
        backward = trace((0, 0), outward+'rr'+inverse(outward), bounded=False)[len(forward):]
        self.assertEqual(backward, list(reversed([(0, 0)]+forward[:-1])))
        panel = atlas_panel()
        self.assertEqual(trace((0, 0), panel, bounded=False)[-1], (0, 0))
        self.assertEqual((panel.count('r')-panel.count('l')) % 4, 1)

    def test_short_fixed_tiles_cycle_without_solving_the_new_lessons(self):
        problems = json.loads((ROOT / 'Sources/HerbertCore/Resources/original-problems.json').read_text())[-10:]
        tiles = []
        for length in range(1, 7):
            for commands in itertools.product('slr', repeat=length):
                tile = ''.join(commands)
                if 's' in tile and not any(tile == tile[:k]*(length//k)
                                           for k in range(1, length) if length % k == 0):
                    tiles.append(tile)
        self.assertEqual(len(tiles), 935)
        for problem in problems:
            cells = ''.join(problem['rows'])
            targets = {point: 1 << bit for bit, point in
                       enumerate(i for i, cell in enumerate(cells) if cell == 'o')}
            complete = (1 << len(targets))-1
            for tile in tiles:
                position, heading, phase, lit = cells.index('u'), 0, 0, 0
                seen = set()
                while (position, heading, phase, lit) not in seen:
                    seen.add((position, heading, phase, lit))
                    command = tile[phase]
                    phase = (phase+1) % len(tile)
                    if command != 's':
                        heading = (heading+(1 if command == 'r' else -1)) % 4
                        continue
                    dx, dy = [(0, -1), (1, 0), (0, 1), (-1, 0)][heading]
                    x, y = position % 25+dx, position//25+dy
                    if 0 <= x < 25 and 0 <= y < 25 and cells[y*25+x] != 'x':
                        position = y*25+x
                        if cells[position] == '*':
                            lit = 0
                        lit |= targets.get(position, 0)
                        self.assertNotEqual(lit, complete, (problem['lesson']['order'], tile))


if __name__ == '__main__':
    unittest.main()
