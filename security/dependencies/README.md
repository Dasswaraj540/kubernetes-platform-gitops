# Dependency scanning

Both pipelines resolve the runtime classpath and scan it with Trivy in filesystem mode:

```
./mvnw -q -B -ntp dependency:copy-dependencies -DincludeScope=runtime -DoutputDirectory=target/deps

trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 \
  --ignorefile security/dependencies/.trivyignore \
  app/target/deps
```

`dependency:copy-dependencies` writes the exact resolved compile+runtime jars to
`target/deps`; Trivy scans each one. A HIGH or CRITICAL finding with an available fix fails
the build. (Trivy's `fs` mode does not descend into a repackaged Spring Boot fat jar, so the
loose dependency directory is scanned instead.)

## Ignore list

`.trivyignore` in this directory is the only place a finding is silenced, and it starts
empty. Add an entry only with:

- the specific vulnerability ID (`CVE-…` or `GHSA-…`), never a broad match,
- a trailing comment naming the tracking issue and a review date,
- the shortest-lived exception that works.

Entries whose review date has passed should fail review. Prefer bumping the offending
dependency (usually a Spring Boot BOM bump) over adding an entry.

## Why not OWASP Dependency-Check

Recent `dependency-check-maven` releases require an NVD API key and will not run without
one, which would make the pipeline depend on an externally provisioned secret. Trivy's
vulnerability database is public and needs no key.
