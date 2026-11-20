use crate::ProcessUsage;

#[derive(Default)]
pub(super) struct Sampler {
    #[cfg(target_os = "linux")]
    previous: Option<(std::time::Instant, u64)>,
}

impl Sampler {
    pub(super) fn sample(&mut self, reset: bool) -> ProcessUsage {
        #[cfg(target_os = "linux")]
        {
            use std::{fs, time::Instant};

            if reset {
                self.previous = None;
            }
            let stat = fs::read_to_string("/proc/self/stat").ok();
            let Some((ticks, resident_pages)) = stat.as_deref().and_then(parse_stat) else {
                self.previous = None;
                return ProcessUsage::default();
            };
            let now = Instant::now();
            let cpu_percent = self
                .previous
                .replace((now, ticks))
                .and_then(|(then, old_ticks)| {
                    let elapsed = now.duration_since(then).as_secs_f64();
                    let tick_rate = rustix::param::clock_ticks_per_second();
                    (elapsed > 0.0 && tick_rate > 0).then(|| {
                        100.0 * ticks.saturating_sub(old_ticks) as f64 / tick_rate as f64 / elapsed
                    })
                });
            let resident_mib =
                resident_pages as f64 * rustix::param::page_size() as f64 / (1024.0 * 1024.0);
            ProcessUsage {
                cpu: cpu_percent
                    .map(|value| format!("{value:.1}%").into())
                    .unwrap_or_default(),
                memory: format!("{resident_mib:.1} MiB").into(),
            }
        }
        #[cfg(not(target_os = "linux"))]
        {
            let _ = reset;
            ProcessUsage::default()
        }
    }
}

#[cfg(target_os = "linux")]
fn parse_stat(contents: &str) -> Option<(u64, u64)> {
    // The process name may contain spaces and closing parentheses.
    let (_, fields) = contents.rsplit_once(')')?;
    let mut fields = fields.split_whitespace();
    // The first token after the name is field 3. CPU times are fields 14 and 15, RSS is 24.
    let user_ticks: u64 = fields.nth(11)?.parse().ok()?;
    let system_ticks: u64 = fields.next()?.parse().ok()?;
    let resident_pages = fields.nth(8)?.parse().ok()?;
    Some((user_ticks.checked_add(system_ticks)?, resident_pages))
}

#[cfg(all(test, target_os = "linux"))]
mod tests {
    use super::*;

    #[test]
    fn reads_process_times_and_resident_pages() {
        let stat = "123 (touch ) ui) R 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24";
        assert_eq!(parse_stat(stat), Some((29, 24)));
        assert_eq!(parse_stat("123 (touch) R"), None);
    }
}
