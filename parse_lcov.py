import sys

def parse_lcov(file_path):
    current_file = None
    file_stats = {}
    
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('SF:'):
                current_file = line[3:]
                file_stats[current_file] = {'found': 0, 'hit': 0}
            elif line.startswith('DA:'):
                parts = line[3:].split(',')
                file_stats[current_file]['found'] += 1
                if int(parts[1]) > 0:
                    file_stats[current_file]['hit'] += 1
                    
    print(f"{'File':<50} {'Hit':<8} {'Total':<8} {'Coverage'}")
    print("-" * 75)
    for f, stat in sorted(file_stats.items()):
        pct = (stat['hit'] / stat['found'] * 100) if stat['found'] > 0 else 0
        print(f"{f:<50} {stat['hit']:<8} {stat['found']:<8} {pct:.2f}%")

parse_lcov('coverage/lcov.info')
