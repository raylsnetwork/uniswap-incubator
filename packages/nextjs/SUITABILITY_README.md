# Suitability Questionnaire

This is a suitability questionnaire to assess investor risk profiles. The questionnaire was developed following regulatory guidelines and financial market best practices.

## Features

### Questionnaire Structure
- **5 main questions** about investor profile
- **4 answer options** for each question (values from 0 to 3)
- **Weight system** for different questions
- **Step-by-step navigation** with progress bar
- **Detailed result** with risk classification

### Questionnaire Questions

1. **Investment Experience** (Weight: 3)
   - No experience (0)
   - Little experience (1)
   - Moderate experience (2)
   - Extensive experience (3)

2. **Risk Tolerance** (Weight: 3)
   - Very conservative (0)
   - Conservative (1)
   - Moderate (2)
   - Aggressive (3)

3. **Time Horizon** (Weight: 2)
   - Short term < 1 year (0)
   - Medium term 1-5 years (1)
   - Long term 5-10 years (2)
   - Very long term > 10 years (3)

4. **Financial Objective** (Weight: 2)
   - Preserve capital (0)
   - Regular income (1)
   - Moderate growth (2)
   - Aggressive growth (3)

5. **Market Knowledge** (Weight: 1)
   - Beginner (0)
   - Basic (1)
   - Intermediate (2)
   - Advanced (3)

### Risk Profile Calculation

- **Maximum Total Score**: 33 points (3×3 + 3×3 + 2×3 + 2×3 + 1×3)
- **Normalized Profile**: 0-15 points
- **Risk Classification**:
  - 0-5: Conservative
  - 6-10: Moderate
  - 11-15: Sophisticated

### Suitability Criteria

- **Suitable**: Profile ≥ 3 points
- **Unsuitable**: Profile < 3 points

## Technologies Used

- **Frontend**: Next.js 15 with TypeScript
- **UI**: Tailwind CSS + DaisyUI
- **State**: React Hooks
- **Navigation**: Next.js App Router

## File Structure

```
packages/nextjs/
├── app/
│   └── suitability/
│       └── page.tsx              # Questionnaire page
├── components/
│   └── SuitabilityQuestionnaire.tsx  # Main component
├── hooks/
│   └── useSuitabilityVerifier.ts     # Hook with calculation logic
└── types/
    └── suitability.ts                # TypeScript types
```

## How to Use

1. **Access the page**: `http://localhost:3000/suitability`
2. **Answer the questions**: Navigate through the 5 questions
3. **View the result**: See your risk profile and suitability
4. **Retake if needed**: Use the "Retake Questionnaire" button

## Features

### User Interface
- ✅ Step-by-step navigation
- ✅ Progress bar
- ✅ Visual progress indicators
- ✅ Responsive design
- ✅ Visual feedback for selections

### Results
- ✅ Risk profile (0-15)
- ✅ Classification (Conservative/Moderate/Sophisticated)
- ✅ Total score
- ✅ Suitability status
- ✅ Answer summary

### User Experience
- ✅ Answer validation
- ✅ Intuitive navigation
- ✅ Immediate feedback
- ✅ Possibility to retake

## Next Steps

1. **Smart Contract Integration**: Connect with SuitabilityVerifier contract
2. **ZK Proofs**: Implement zero-knowledge proof generation
3. **Persistence**: Save results on blockchain
4. **History**: Maintain evaluation history
5. **Reports**: Generate detailed reports

## Development

### Run Locally
```bash
cd packages/nextjs
yarn dev
```

### Production Build
```bash
cd packages/nextjs
yarn build
```

### Tests
```bash
cd packages/nextjs
yarn test
```

## Contributing

To contribute with questionnaire improvements:

1. Maintain the 5-question structure
2. Preserve the weight system
3. Test responsiveness
4. Validate accessibility
5. Document changes

## License

This project is under the MIT license. See the LICENSE file for more details.