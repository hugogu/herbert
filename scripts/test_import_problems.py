import unittest
from import_problems import parse_board, parse_listing


class ImportTests(unittest.TestCase):
    def test_preserves_original_identity_and_html_entities(self):
        source = '<tr class="prob_yet problem"><td>0001</td><td><a>A &amp; B</a></td><td><a>author</a></td><td>4</td><td>4</td><td>10</td></tr>'
        result = parse_listing(source)[0]
        self.assertEqual(result['id'], 1)
        self.assertEqual(result['title'], 'A & B')
        self.assertEqual(result['byteLimit'], 4)
        self.assertEqual(result['author'], 'author')

    def test_validates_original_board_shape_and_start(self):
        source = 'u' + 'o' + '.' * 623 + '\n4'
        rows, limit = parse_board(source)
        self.assertEqual((len(rows), len(rows[0]), limit), (25, 25, 4))
        for invalid in [source[:-5], '<html>Error</html>', '.' * 625 + '\n4', source.replace('o', 'z')]:
            with self.assertRaises(ValueError):
                parse_board(invalid)

    def test_null_placeholder_is_not_imported(self):
        source = '<tr class="prob_yet problem"><td>0000</td><td>Null</td><td>admin</td><td>0</td><td></td><td>0</td></tr>'
        self.assertEqual(parse_listing(source), [])


if __name__ == '__main__':
    unittest.main()
