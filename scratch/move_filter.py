import os

filepath = r'c:\rental\lib\screens\home_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    c = f.read()

# 1. Rename 'Buy' to 'Explore' in the bottom nav bar
c = c.replace(
    "(label: 'Buy', activeIcon: CupertinoIcons.bag_fill, inactiveIcon: CupertinoIcons.bag),",
    "(label: 'Explore', activeIcon: CupertinoIcons.bag_fill, inactiveIcon: CupertinoIcons.bag),"
)

# 2. Rename 'BUY' to 'EXPLORE' in the integrated tabs
c = c.replace(
    "(label: 'BUY', index: 3, icon: CupertinoIcons.lock_fill),",
    "(label: 'EXPLORE', index: 3, icon: CupertinoIcons.lock_fill),"
)

# 3. Find the SORT button inside _buildExploreMarketplaceView and remove the FILTER button
filter_str = """                  const SizedBox(width: 10),
                  // ── FILTER button ──────────────────────────────
                  BouncingButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchScreen(
                            properties: _allProperties,
                            currentPosition: _effectivePosition,
                            autoOpenFilters: true,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'FILTER',
                            style: TextStyle(fontFamily: 'ProximaNova', 
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.swiggyOrange,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Icon(
                            CupertinoIcons.slider_horizontal_3,
                            size: 14,
                            color: AppTheme.swiggyGreen,
                          ),
                        ],
                      ),
                    ),
                  ),"""

if filter_str in c:
    print('Filter string found! Removing it from Explore page.')
    c = c.replace(filter_str, '', 1)  # replace first occurrence
else:
    print('Filter string NOT found in first occurrence!')

# 4. Insert the FILTER button next to the SORT button in _buildSwiggyHeader (the home page header)
sort_str_in_home = """                  // ── SORT button ──────────────────────────────
                  BouncingButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showSortBottomSheet();
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'SORT',
                            style: TextStyle(fontFamily: 'ProximaNova', 
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.swiggyOrange,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Icon(
                            CupertinoIcons.sort_down,
                            size: 14,
                            color: AppTheme.swiggyGreen,
                          ),
                        ],
                      ),
                    ),
                  ),"""

# Find the LAST occurrence of sort_str_in_home (which should be in _buildSwiggyHeader)
last_index = c.rfind(sort_str_in_home)
if last_index != -1:
    print('Sort string found in SwiggyHeader. Inserting FILTER button next to it.')
    # Create the replacement block which includes both SORT and FILTER buttons
    replacement = sort_str_in_home + '\n' + filter_str
    
    # Check if we already inserted it previously to avoid double-insertion
    # If the text immediately following last_index + len(sort_str_in_home) is the filter_str, skip
    next_chunk = c[last_index + len(sort_str_in_home) : last_index + len(sort_str_in_home) + 50]
    if 'FILTER button' not in next_chunk:
        c = c[:last_index] + replacement + c[last_index + len(sort_str_in_home):]
    else:
        print('FILTER button already exists in SwiggyHeader. Skipping insertion.')
else:
    print('Sort string NOT found in SwiggyHeader!')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(c)

print('Done.')
