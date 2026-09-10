# Dependency scanning

Both pipelines run OWASP Dependency-Check against the Maven build:

```
./mvnw -B -ntp org.owasp:dependency-check-maven:check \
  -DfailBuildOnCVSS=7 \
  -Dformats=HTML,SARIF \
  -DsuppressionFiles=../security/dependencies/dependency-check-suppressions.xml
```

- `failBuildOnCVSS=7` fails the build on any unsuppressed finding with CVSS ≥ 7.
- Reports (`app/target/dependency-check-report.*`) are archived by the pipeline.

## Suppressions

`dependency-check-suppressions.xml` is the only place findings are silenced, and it starts
empty. Add an entry only with:

- a specific `packageUrl` or `cve` (never a blanket suppress),
- a `<notes>` line naming the tracking issue and a review date,
- the narrowest scope that works.

Example shape:

```xml
<suppress until="2026-12-01Z">
  <notes>PLAT-123 - transitive via X, no fixed release yet; re-check monthly.</notes>
  <packageUrl regex="true">^pkg:maven/com\.example/thing@.*$</packageUrl>
  <cve>CVE-2025-00000</cve>
</suppress>
```

Suppressions with a past `until` date should fail review.
