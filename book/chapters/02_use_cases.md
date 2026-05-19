# Use Cases

Confidential Computing applies whenever you need to run computation on sensitive data in an environment you don't fully control. Here are the primary use cases.

## 1. Secure AI Inference

```{figure} ../images/page_06.png
:alt: Secure Inference Use Case
:align: center
Run inference on trained models in a public cloud without exposing model weights to the cloud provider, other tenants, or API users. Supports LLM chatbots fine-tuned on private data and Confidential RAG LLMs.
```

**Problem:** You've trained a proprietary AI model (or fine-tuned an LLM on private data). You want to serve it via API in a public cloud — but you don't want the cloud provider, or other tenants, to extract your model weights.

**Relevant patterns:**
- Run inference on a trained model in public cloud without exposing model weights to the cloud provider
- Run LLM chatbots fine-tuned on private data
- Confidential RAG (Retrieval Augmented Generation) with private document stores

## 2. Secure Chatbot / LLM Serving

```{figure} ../images/page_07.png
:alt: Secure Chatbot Use Case
:align: center
Protect user data sent for inference from the model provider. The TEE ensures that even the model owner's infrastructure cannot see user queries or conversation history.
```

This is subtly different from secure inference — here the model is known/public, but user *inputs* are sensitive. The TEE protects user queries, conversation history, and fine-tuned model variants.

## 3. Secure AI Training

```{figure} ../images/page_08.png
:alt: Secure Training Use Case
:align: center
Use additional GPU capacity in a third-party data center for training on private data. Supports federated learning across multiple organizations.
```

**Problem:** Your GPU cluster is too small. You want to use a third-party data center's capacity — but your training data is sensitive (medical records, financial data, proprietary datasets).

## 4. Secure Multi-Party Analytics

```{figure} ../images/page_09.png
:alt: Secure Multi-Party Analytics Use Case
:align: center
Multiple data owners collaborate on shared analytics (e.g., fraud detection across banks) without any party seeing the others' raw data. Enables data cleanrooms and Confidential Spaces.
```

**Applications:**
- Fraud detection across financial institutions
- Healthcare research across hospital networks
- **Data cleanrooms** — collaborative analytics without raw data sharing

## 5. Secure CI/CD Pipelines

```{figure} ../images/page_10.png
:alt: Secure CI/CD Pipelines Use Case
:align: center
Protect pipeline jobs and the secrets used for artifact signing inside a TEE, preventing a compromised CI runner from stealing signing keys or injecting malicious code.
```

## 6. Segregating Admin Roles

```{figure} ../images/page_11.png
:alt: Segregating Admin Roles
:align: center
Confidential Computing enables clean separation of duties — infrastructure admins, cluster admins, and workload admins each operate at their own trust boundary without being able to access each other's secrets.
```

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
