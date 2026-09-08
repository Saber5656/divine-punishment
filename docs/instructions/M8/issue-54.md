# Non-lethal play (#54)

G performs a rear strike within1.2m with clear world/door line of sight. The target loses no health, falls unconscious for60 seconds, and does not wake to noise. Selecting rope and using the tool beside a sleeping/unconscious target binds it after2 seconds; moving away or changing equipment cancels without consuming rope. Bound bodies remain alive, never wake, expose a RESTRAINED anomaly and use the existing carry/storage system.

Mission forbidden_actions gate lethal attack/parry, assassination prompt/execution, dart use and aiming. SceneDirector applies authored loadouts before the entry checkpoint and displays non-lethal controls. Any kill under FORBIDDEN fails before objective completion and automatically retries the checkpoint, with a localized explanation.

M9's one-strike award uses knockouts >=80% of distinct enemy contacts (combat alerts or knockouts); zero-contact evasion qualifies. Checkpoint state retains contact receipts and noise-wake policy. The M9 level itself remains tracked by #72.

See [validation](../../qa-logs/nonlethal54/README.md).
