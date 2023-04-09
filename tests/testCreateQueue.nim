discard """
  output: '''
1 2
2 4
4 8
8 16
4096 8192
'''
"""
import nimuring

for entries in @[1, 2, 4, 8, 4096]:
  var q = newQueue(entries, {})
  echo q.params.sqEntries, " ", q.params.cqEntries