"""
Serveur MCP minimal qui expose la couche sémantique MetricFlow à un agent (Claude).

Pourquoi : l'agent ne doit pas écrire son propre SQL. Il ne peut interroger que
les métriques certifiées définies dans models/semantic/_metrics.yml.

Garde-fous :
- seules les métriques et dimensions déclarées sont acceptées (liste blanche) ;
- aucune requête SQL libre ;
- nombre de lignes limité ;
- chaque réponse rappelle les métriques utilisées (traçabilité).

Lancement : python agent/metrics_mcp_server.py   (depuis la racine du projet dbt)
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

import yaml
from mcp.server.fastmcp import FastMCP

PROJECT_DIR = Path(__file__).resolve().parent.parent
METRICS_FILE = PROJECT_DIR / "models" / "semantic" / "_metrics.yml"
MAX_ROWS = 200
SAFE_NAME = re.compile(r"^[a-z0-9_]+(__[a-z0-9_]+)*$")

mcp = FastMCP("shopping-metrics")


def _metrics() -> dict[str, dict]:
    data = yaml.safe_load(METRICS_FILE.read_text(encoding="utf-8"))
    return {m["name"]: m for m in data["metrics"]}


def _run_mf(args: list[str]) -> str:
    result = subprocess.run(
        ["mf", *args], cwd=PROJECT_DIR, capture_output=True, text=True, timeout=120
    )
    if result.returncode != 0:
        return f"ERREUR MetricFlow : {result.stderr.strip()[-800:]}"
    return result.stdout.strip()


@mcp.tool()
def list_metrics() -> str:
    """Liste les métriques certifiées disponibles, avec leur définition métier."""
    lines = []
    for name, m in _metrics().items():
        desc = (m.get("description") or "").strip().replace("\n", " ")
        lines.append(f"- {name} ({m.get('label', name)}) : {desc}")
    return "\n".join(lines)


@mcp.tool()
def list_dimensions(metric: str) -> str:
    """Liste les dimensions par lesquelles une métrique peut être découpée."""
    if metric not in _metrics():
        return f"Métrique inconnue : {metric}. Utilise list_metrics."
    return _run_mf(["list", "dimensions", "--metrics", metric])


@mcp.tool()
def query_metrics(
    metrics: list[str],
    group_by: list[str] | None = None,
    order_by: list[str] | None = None,
    limit: int = 50,
) -> str:
    """
    Interroge une ou plusieurs métriques certifiées.
    group_by : dimensions au format entité__dimension (ex. customer__customer_segment,
    order__season, product__category) ou metric_time__month.
    order_by : un nom de métrique ou de dimension, préfixé par '-' pour un tri décroissant.
    """
    known = _metrics()
    unknown = [m for m in metrics if m not in known]
    if unknown:
        return f"Métriques non certifiées refusées : {unknown}. Utilise list_metrics."
    for name in (group_by or []) + [o.lstrip("-") for o in (order_by or [])]:
        if not SAFE_NAME.match(name):
            return f"Nom de dimension invalide : {name}"
    args = ["query", "--metrics", ",".join(metrics), "--limit", str(min(limit, MAX_ROWS))]
    if group_by:
        args += ["--group-by", ",".join(group_by)]
    if order_by:
        args += ["--order", ",".join(order_by)]
    out = _run_mf(args)
    return f"{out}\n\n[Source : métriques certifiées {', '.join(metrics)} — MetricFlow]"


if __name__ == "__main__":
    mcp.run()
