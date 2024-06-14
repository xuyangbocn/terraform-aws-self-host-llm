# Setup of an Ollama Deployment

This TF repo setup a ready to use Ollama deployment, except for downloading of models which depends on actual usage.

## Infra setup includes

- A VPC

  - in ap-southeast-1 region
  - three private subnets
  - three public subnets
  - NAT GW
  - VPC endpoints
  - necessary route tables, nacl, default sg

- An EC2

  - arm/x86 instance with GPU (`g5g.xlarge`, or `g4dn.xlarge`) and the corresponding Deep learning AMI
  - hosted in one of the private subnets
  - Ollama installed and exposed over 0.0.0.0:11434
  - GPU monitoring setup to CW custom metrics
  - necessary IAM roles, policy and sg

- An ALB

  - hosted in private subnets across zone a,b,c
  - listener for port 80
  - target group for port 11434 and registered the llm EC2

- An API GW
  - with vpc links to the VPC hosting llm EC2
  - forward POST and GET api to the ALB at port 80
  - including an auto-deploy stage
  - including a pass-thru lambda authenticator, logic can be customized
  - exposing the default api endpoint
  - (Optional) Custom domain name setup to replace the API Gw default endpoint

## How to run setup

- Double check the configs in `local.tf` for VPC, EC2, ALB, API GW in case need to adjust anything
- Run terraform init, plan, apply, destroy accordingly
- The Ollama API (GET, POST) is exposed via the API GW default endpoints url or custom domain name

## How to use Ollama

- Access EC2 using ssm, run `ollama pull <model-name:tag>` to pull the required models. [reference](https://ollama.com/library)
- Ollama API documentation can be found [here](https://github.com/ollama/ollama/blob/main/docs/api.md)
- Feel free to make other use cases of Ollama deployment

## Capacity

`g5g` and `g4dn` xlarge EC2 has a 12GB VRAM GPU, it can support most models that has a size<=14b and quantized at 4q or below.

## Future enhancement or exploration

1. How to host a larger model in singapore? e.g. 70b. Use instance with multiple GPU? Use other CSP?
2. How to make LLM server more scalable for high number of user requests?
3. Deploy using Vllm VS Ollama
