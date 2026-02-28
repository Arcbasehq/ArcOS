# ArcOS Framework

ArcOS Framework is a modular Windows optimization framework designed to streamline, refine, and enhance a clean Windows installation without modifying or redistributing Windows itself.

ArcOS Framework applies structured system-level configuration changes through PowerShell automation while prioritizing stability, reversibility, and Windows Update compatibility.

---

## Important

ArcOS Framework does NOT:

- Replace Windows
- Distribute modified Windows ISOs
- Patch or tamper with Windows system binaries

ArcOS Framework runs on top of an official, licensed Windows installation.

---

## Features

ArcOS Framework now includes:

### Core Features
- **Telemetry & Privacy**: Disable Windows telemetry and data collection
- **AppX Management**: Remove bloatware while preserving essential apps
- **Service Optimization**: Intelligent service configuration for performance
- **Task Scheduling**: Manage background tasks to reduce system load
- **Registry Optimization**: Apply performance-enhancing registry tweaks
- **Group Policy**: Configure system policies for privacy and security
- **UI Performance**: Optimize visual effects and animations
- **Wallpaper Customization**: System-wide wallpaper management
- **User Profile**: Avatar and personalization settings

### Advanced Features
- **Modular Engine System**: 11 independent optimization engines
- **Profile System**: Pre-configured optimization profiles
- **Configuration Management**: Comprehensive JSON-based configuration
- **Rollback System**: Complete system state snapshots and restoration
- **Validation System**: Configuration validation and error checking
- **Detailed Reporting**: Comprehensive execution reports and logs
- **Interactive CLI**: User-friendly menu-driven interface
- **Risk Management**: Engine risk classification and profile-based filtering

### Profiles
- **Balanced**: Recommended for most users (default)
- **Aggressive**: Maximum performance optimizations
- **Stable**: Conservative changes only
- **Performance**: Focus on speed improvements

---

## Usage

### Basic Usage
```powershell
# Run with default configuration
.\.\main.ps1

# Run with specific profile
$env:ARCOS_PROFILE="aggressive"
.\.\main.ps1

# Rollback to previous state
.\.\main.ps1 --rollback

# Rollback to specific snapshot
.\.\main.ps1 --rollback rollback-20231201-143022.json

# Show help
.\.\main.ps1 --help
```

### Interactive CLI
```powershell
.\.\cli.ps1
```

### Configuration
Edit `config.json` to customize:
- Enable/disable individual engines
- Configure engine-specific settings
- Set advanced options (auto-reboot, logging, etc.)
- Choose optimization profile

---

## Project Structure
