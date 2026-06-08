# Use Cases

Here are the primary use cases of confidential computing.

## 1. Secure AI Inference

**Problem:** 

- You've trained a proprietary AI model (or fine-tuned an LLM on private data). You want to serve it via API in a public cloud — but you don't want the cloud provider, or other tenants, to extract your model weights.

**Relevant patterns:**

- Run inference on a trained model in public cloud without exposing model weights to the cloud provider
- Run LLM chatbots fine-tuned on private data
- Confidential RAG (Retrieval Augmented Generation) with private document stores

```{figure} ../images/page_06.png
:alt: Secure Inference Use Case
:align: center
```

## 2. Secure Chatbot / LLM Serving

This is subtly different from secure inference — here the model is known/public, but user *inputs* are sensitive. The TEE protects user queries, conversation history, and fine-tuned model variants.

```{figure} ../images/page_07.png
:alt: Secure Chatbot Use Case
:align: center
```

## 3. Secure AI Training

**Problem:**

- Your GPU cluster is too small. You want to use a third-party data center's capacity — but your training data is sensitive (medical records, financial data, proprietary datasets).


```{figure} ../images/page_08.png
:alt: Secure Training Use Case
:align: center
```

## 4. Secure Multi-Party Analytics

**Problem:**

- Multiple data owners want to collaborate on shared analytics (e.g., fraud detection across banks) without any owner seeing the others' raw data.

**Relevant patterrns:**

- Fraud detection across financial institutions
- Healthcare research across hospital networks
- Data clean rooms

```{figure} ../images/page_09.png
:alt: Secure Multi-Party Analytics Use Case
:align: center
```

## 5. Secure CI/CD Pipelines

**Problem:**

- Your CI/CD pipeline runs on shared infrastructure (GitHub Actions, GitLab CI, etc.). You want to protect your secrets (API keys, tokens, certificates) from being exposed to the infrastructure provider.

## 6. Segregating Admin Roles

**Problem:**

- You want to separate infrastructure admins (who manage hosts/hypervisors) from workload admins (who manage specific workloads). With Confidential Computing, infrastructure admins can't see workload secrets.

This enables a clean separation that was previously impossible:

| Admin Role | Controls | Can See Workload Secrets? |
|---|---|---|
| **Infrastructure Admin** | Hosts, hypervisors, physical machines, networks | ✗ No |
| **Cluster Admin** | K8s control plane, nodes, networking, RBAC, namespaces | ✗ No |
| **Workload Admin** | Specific workloads and their secrets | ✔ Yes |

## Use Case Summary

| Use Case | Threat Being Mitigated | Key Benefit |
|---|---|---|
| Secure Inference | Cloud provider steals model | IP protection |
| Secure Chatbot | Provider reads user queries | User privacy |
| Secure Training | Data center steals training data | Data sovereignty |
| Multi-party Analytics | Peers see raw data | Collaboration without exposure |
| CI/CD Protection | Compromised runner steals keys | Supply chain security |
| Admin Role Segregation | Malicious admin reads secrets | Zero-trust operations |

:::{tip}
**Defense in Depth:** Even for existing applications without obvious "sensitive data," Confidential Computing adds a layer of protection against insider threats and sophisticated attackers with infrastructure access. Regulated industries (healthcare, finance, government) can use it to satisfy compliance requirements that mandate data protection even from infrastructure operators.
:::
