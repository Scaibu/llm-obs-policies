#!/usr/bin/env python3
"""
Zero-dependency package and feature scaffolder for prediction-pipeline.
Parses canonical JSON templates directly and enforces Guardrails 1-10.
"""

import json
import os
import sys
from pathlib import Path

PACKAGE_NAME = "prediction-pipeline"
FEATURES = [
    "selection_bias_truncation",
    "survivor_bias_detection",
    "collider_stratification_audit",
    "proxy_label_distortion",
    "measurement_error_tracking",
    "heavy_tail_imbalance",
    "covariate_shift_detection",
    "concept_drift_monitoring",
    "label_delay_attribution",
    "temporal_leakage_prevention",
    "non_ergodicity_guard",
    "seasonality_aliasing_filter",
    "confounder_identification",
    "performative_prediction_audit",
    "endogenous_feedback_control",
    "omitted_variable_analysis",
    "counterfactual_evaluation",
    "simultaneous_causality_resolver",
    "dimensionality_sparsity_guard",
    "multicollinearity_detector",
    "ood_overconfidence_mitigation",
    "simpsons_paradox_analyzer",
    "regression_to_mean_adjuster",
    "asymmetric_cost_optimizer",
    "training_serving_skew_audit",
    "silent_pipeline_corruption_probe",
    "adversarial_perturbation_defense",
    "cascade_failure_circuit_breaker",
    "target_leakage_scanner",
    "uncertainty_decomposition_engine",
]

def main():
    repo_root = Path(__file__).resolve().parent.parent
    base_dir = repo_root / PACKAGE_NAME
    templates_dir = repo_root / "policy-orchestrator" / "src" / "features" / "folder_scaffold" / "templates"
    
    pkg_template_path = templates_dir / "0-rule-package-structure.template.json"
    feat_template_path = templates_dir / "1-rule-backend-feature-structure.template.json"
    
    if not pkg_template_path.exists():
        print(f"Error: Package template not found at {pkg_template_path}")
        sys.exit(1)
    if not feat_template_path.exists():
        print(f"Error: Feature template not found at {feat_template_path}")
        sys.exit(1)
        
    with open(pkg_template_path, "r", encoding="utf-8") as f:
        pkg_template = json.load(f)
        
    with open(feat_template_path, "r", encoding="utf-8") as f:
        feat_template = json.load(f)
        
    print(f"Scaffolding package '{PACKAGE_NAME}' at {base_dir}...")
    base_dir.mkdir(parents=True, exist_ok=True)
    
    # 1. Package-level scaffolding
    created_files = 0
    for node in pkg_template.get("nodes", []):
        rel_path = node["path"].replace("PACKAGE_NAME", PACKAGE_NAME)
        file_path = base_dir / rel_path
        file_path.parent.mkdir(parents=True, exist_ok=True)
        content = node.get("content", "").replace("PACKAGE_NAME", PACKAGE_NAME)
        if not file_path.exists():
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(content)
            created_files += 1

    # 2. Scaffolding all 30 features
    for feat in FEATURES:
        for node in feat_template.get("nodes", []):
            rel_path = node["path"].replace("FEATURE_NAME", feat).replace("PACKAGE_NAME", PACKAGE_NAME)
            file_path = base_dir / rel_path
            file_path.parent.mkdir(parents=True, exist_ok=True)
            content = node.get("content", "").replace("FEATURE_NAME", feat).replace("PACKAGE_NAME", PACKAGE_NAME)
            if not file_path.exists():
                with open(file_path, "w", encoding="utf-8") as f:
                    f.write(content)
                created_files += 1
                
        # Additional canonical testing pyramid files per 1-feature-folder-writing-rule.md
        extra_tests = [
            f"src/features/{feat}/tests/{feat}.workflow.test.py",
            f"src/features/{feat}/tests/{feat}.schema.test.py",
            f"src/features/{feat}/tests/{feat}.integration.test.py",
        ]
        for t_rel in extra_tests:
            t_path = base_dir / t_rel
            t_path.parent.mkdir(parents=True, exist_ok=True)
            if not t_path.exists():
                with open(t_path, "w", encoding="utf-8") as f:
                    f.write(f'"""Canonical verification test suite for {feat}."""\n')
                created_files += 1

    # 3. Ensure Guardrail 6: Mandatory .gitkeep in every directory
    gitkeeps_added = 0
    for root, dirs, files in os.walk(base_dir):
        # ignore __pycache__ or .git if any
        if "__pycache__" in root or ".git" in root:
            continue
        gitkeep_path = Path(root) / ".gitkeep"
        if not files and not gitkeep_path.exists():
            with open(gitkeep_path, "w", encoding="utf-8") as f:
                f.write("")
            gitkeeps_added += 1

    print(f"Successfully scaffolded {created_files} canonical files and {gitkeeps_added} .gitkeep files across 30 features.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
