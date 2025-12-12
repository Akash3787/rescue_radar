# Detection Logic Explanation

## How Detection Works

The ESP32 now uses **smart detection logic** that distinguishes between:
- **PERSON DETECTED** - Active movement/variation detected
- **REST STATE** - Stable readings for extended period (radar idle)
- **NO PERSON** - No valid readings

## Detection Algorithm

### 1. Movement Detection
- Compares current reading with previous reading
- If variation > 5cm → **PERSON DETECTED** (movement detected)
- Resets stable timer when movement detected

### 2. Rest State Detection
- Tracks how long readings have been stable (unchanged)
- If stable for **10 seconds** → **REST STATE** = **NOT DETECTED**
- This means radar is idle, sending same values continuously

### 3. First Reading
- First valid reading → Assumes **PERSON DETECTED**
- Starts tracking stability from this point

## Configuration

You can adjust these values in the code:

```cpp
const unsigned long STABLE_THRESHOLD = 10000;  // 10 seconds = rest state
const float VARIATION_THRESHOLD = 5.0;  // 5cm variation = movement
```

### Adjusting Rest State Time
- **Shorter** (e.g., 5000ms = 5 seconds): Faster to detect rest state
- **Longer** (e.g., 30000ms = 30 seconds): Slower to detect rest state

### Adjusting Variation Threshold
- **Smaller** (e.g., 2.0cm): More sensitive to small movements
- **Larger** (e.g., 10.0cm): Only detects significant movements

## Example Scenarios

### Scenario 1: Person Moving
```
Reading 1: 250cm → DETECTED (first reading)
Reading 2: 255cm → DETECTED (5cm variation = movement)
Reading 3: 260cm → DETECTED (5cm variation = movement)
```

### Scenario 2: Person Stationary
```
Reading 1: 250cm → DETECTED (first reading)
Reading 2: 250cm → DETECTED (stable, but < 10s)
Reading 3: 250cm → DETECTED (stable, but < 10s)
...
Reading 10: 250cm → NOT DETECTED (stable for 10s = rest state)
```

### Scenario 3: No Person / Radar Idle
```
Reading 1: 0cm → NOT DETECTED (no valid reading)
Reading 2: 0cm → NOT DETECTED (no valid reading)
```

### Scenario 4: Radar Rest State (Sending Same Value)
```
Reading 1: 500cm → DETECTED (first reading)
Reading 2: 500cm → DETECTED (stable, but < 10s)
Reading 3: 500cm → DETECTED (stable, but < 10s)
...
Reading 10: 500cm → NOT DETECTED (stable for 10s = rest state)
```

## App Behavior

### When ESP32 sends `detected: false`:
- **Mapping Interface**: Victim won't appear on radar (filters by `detected: true`)
- **Readings Page**: Shows "NO PERSON" status
- **Graph Page**: Still shows data (shows all readings)

### When ESP32 sends `detected: true`:
- **Mapping Interface**: Victim appears on radar
- **Readings Page**: Shows "PERSON DETECTED" status
- **Graph Page**: Shows data normally

## Benefits

1. **Accurate Status**: App reflects actual detection state
2. **Reduces False Positives**: Rest state readings marked as not detected
3. **Movement-Based**: Only detects when there's actual variation
4. **Configurable**: Easy to adjust thresholds for your use case

## Testing

To test the detection logic:

1. **Movement Test**: Move object in front of sensor → Should show DETECTED
2. **Rest State Test**: Keep object stationary for 10+ seconds → Should show NOT DETECTED
3. **No Object Test**: Remove object → Should show NOT DETECTED

Monitor Serial output to see detection status changes in real-time.
