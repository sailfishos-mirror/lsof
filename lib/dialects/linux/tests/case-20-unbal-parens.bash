#!/bin/bash
source tests/common.bash

TARGET=$tcasedir/unbal_parens

r=0

test_pattern() {
    local pattern="$1"
    local expected="$2"
    local pid
    local output
    local comm
    
    $TARGET "$pattern" | {
        read pid
        if [ -z "$pid" ]; then
            echo "FAIL: Failed to start helper process"
            exit 1
        fi
        
        # Give /proc time to update
        sleep 0.2
        
        # Check that lsof finds the process
        output=$($lsof -p $pid 2>/dev/null)
        if ! grep -Fq "$pid" <<<"$output"; then
            echo "FAIL: lsof did not find process with comm='$pattern'"
            echo "pid: $pid"
            kill $pid 2>/dev/null
            exit 1
        fi
        
        # Check that the reported command name matches expected
        comm=$($lsof -p $pid -Fc 2>/dev/null | grep '^c' | head -1 | sed 's/^c//')
        if [ "$comm" != "$expected" ]; then
            echo "FAIL: comm mismatch for pattern='$pattern'"
            echo "  expected: '$expected'"
            echo "  got:      '$comm'"
            kill $pid 2>/dev/null
            exit 1
        fi
        
        echo "PASS: pattern='$pattern' comm='$comm'"
        kill $pid 2>/dev/null
        exit 0
    }
    
    if [ $? -ne 0 ]; then
        r=1
    fi
}

{
    # Test various unbalanced parenthesis patterns
    test_pattern "test(" "test(" || r=1
    test_pattern "test)" "test)" || r=1
    test_pattern "a(b)c" "a(b)c" || r=1
    test_pattern "a(b)c)d)e" "a(b)c)d)e" || r=1
    test_pattern "((" "((" || r=1
    test_pattern "))" "))" || r=1
    test_pattern "((()))" "((()))" || r=1
    test_pattern "(((" "(((" || r=1
    test_pattern ")))" ")))" || r=1

    # Test newline in comm is replaced with '?'
    test_pattern "NEWLINE" "a?b" || r=1
    
    exit $r
} >> $report 2>&1