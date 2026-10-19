# Technical report

The report is written in LaTeX in [`report/main.tex`](report/main.tex) and compiled to PDF by CI on every push (the `report-pdf` artifact of the latest workflow run). A copy of the final PDF, `report/main.pdf`, is committed at submission time.

Contents, in the order the handout asks for them:

1. Deployment overview and diagram ([`diagram.svg`](diagram.svg))
2. Docker Compose inside the VM — observations (Part 2)
3. Kubernetes — Deployment, Service, access methods, Pod replacement (Part 3)
4. Controlled troubleshooting — the Service selector (Part 4)
5. OpenStack deployment analysis, 500–750 words (Part 5)
6. CS 554 extension — resource settings and the readiness experiment, 200–300 words

References are in [`report/references.bib`](report/references.bib) and listed at the end of the PDF; a plain-text list is in [`references.md`](references.md).
