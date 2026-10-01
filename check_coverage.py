import sys

def check_coverage(file_path):
    lines_found = 0
    lines_hit = 0
    with open(file_path, 'r') as f:
        for line in f:
            if line.startswith('DA:'):
                lines_found += 1
                parts = line.strip().split(',')
                if int(parts[1]) > 0:
                    lines_hit += 1
                    
    if lines_found == 0:
        return 0.0
    return (lines_hit / lines_found) * 100

print(f"Coverage: {check_coverage('coverage/lcov.info'):.2f}%")
