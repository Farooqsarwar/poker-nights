import os
import re

file_path = 'lib/screens/tournament/admin_dashboard_screen.dart'
if os.path.exists(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        text = f.read()
    
    # Let's find out how the status is rendered
    if 'game.addOnOvertime' not in text:
        # Check if status text exists
        # Actually I can just look at admin_dashboard_screen.dart using view_file or find the status text
        pass

