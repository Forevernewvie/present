import sys

def parse_lcov(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()
        
    current_file = None
    file_stats = {}
    
    for line in lines:
        line = line.strip()
        if line.startswith('SF:'):
            current_file = line[3:]
            file_stats[current_file] = {'found': 0, 'hit': 0, 'missed_lines': []}
        elif line.startswith('LF:'):
            file_stats[current_file]['found'] = int(line[3:])
        elif line.startswith('LH:'):
            file_stats[current_file]['hit'] = int(line[3:])
        elif line.startswith('DA:'):
            parts = line[3:].split(',')
            line_num = int(parts[0])
            hits = int(parts[1])
            if hits == 0:
                file_stats[current_file]['missed_lines'].append(line_num)
            
    for f, stats in file_stats.items():
        if not (f.startswith('lib/services') or f.startswith('lib/providers') or f.startswith('lib/models')):
            continue
        if stats['found'] > 0:
            cov = stats['hit'] / stats['found'] * 100
            if cov < 100.0:
                print(f"{f}: {cov:.2f}% ({stats['hit']}/{stats['found']})")
                print(f"  Missed lines: {stats['missed_lines']}")

parse_lcov('coverage/lcov.info')
